#!/usr/bin/env node
// Minimal fake of pi's --mode rpc, for exercising the vim plugin without a
// real model. Speaks just enough of the JSONL protocol to drive the plugin's
// event handlers. Protocol shapes follow docs/rpc.md: responses are
//   {"id": ..., "type": "response", "command": ..., "success": true}
// and events are flat JSON lines:
//   {"type": "<event_name>", ...payload}
//
// For each `prompt` it emits a canned reply plus (env-controlled) a thinking
// block and/or tool executions, so the test suite can exercise the handlers:
//   FAKE_PI_THINKING=1     emit thinking_delta frames before the reply
//   FAKE_PI_THINKING_FILE=f  read the thinking text from file f (overrides
//                          FAKE_PI_THINKING_TEXT; for streams >128KB)
//   FAKE_PI_TOOL=bash      which tool to run: bash|read|edit|write|multi|none
//                          (default bash; 'multi' runs bash+read+edit)
//   FAKE_PI_EDIT_PATH=p    args.path for an edit/write tool (reload target)
//   FAKE_PI_TOOLFAIL=1     the tool ends with isError=true
//   FAKE_PI_TITLE=t        the notify title (default 'pi')
//   FAKE_PI_REPLY_PREFIX=  reply prefix (default 'Echo: ')
//   FAKE_PI_TRAILING_NEWLINES=n  append n newline chars to the reply text
//                          (real model text routinely ends in \n / \n\n;
//                          used to test blank-line collapsing in the log)
//   FAKE_PI_DELTAS=json    stream exactly these text deltas (JSON string
//                          array) instead of one delta per character
//   FAKE_PI_REJECT=msg     reject every prompt (response success:false)
//   FAKE_PI_CRASH_MS=n     exit(1) n ms after agent_start, mid-turn
//   FAKE_PI_QUEUE=1        queue prompts sent mid-turn; one agent_settled
//                          after the queue drains (like real pi)
//   FAKE_PI_LIFE_LOG=p     append 'start <pid>' / 'exit <pid>' lines
//   FAKE_PI_TOOL_OUTPUT=t  result text of every tool call (default: none)
//   FAKE_PI_PARALLEL=1     two overlapping write calls (FAKE_PI_EDIT_PATH and
//                          FAKE_PI_EDIT_PATH2), each with its own toolCallId
//   FAKE_PI_LATE_NOTIFY_MS=n  emit one extra 'late note' notify n ms after
//                             agent_settled (a background plugin notification
//                             arriving after the turn, for cursor-park tests)
//
// It keeps running until stdin closes (the plugin :quit!s the job to tear it
// down).
'use strict';

// Record our launch argv (lets tests verify startup flags like --no-session).
// Appended, so a restarted fake (e.g. after :PiClear) leaves one line per launch.
if (process.env.FAKE_PI_ARGV_LOG) {
  try { require('fs').appendFileSync(process.env.FAKE_PI_ARGV_LOG, JSON.stringify(process.argv) + '\n'); } catch {}
}

// Configured model list: FAKE_PI_MODELS='provider:id,provider:id' (default a
// single model). Mirrors pi: set_model validates against the list (Model not
// found when absent) and its data IS the model object, get_available_models
// lists it, cycle_model walks it, get_state reports the current one.
const FAKE_MODELS = (process.env.FAKE_PI_MODELS || 'fake:pi-test').split(',')
  .filter(Boolean)
  .map((s) => { const i = s.indexOf(':'); return { provider: s.slice(0, i), id: s.slice(i + 1), name: s.slice(i + 1) }; });
let fakeModelIdx = 0;

let buf = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (chunk) => {
  buf += chunk;
  let idx;
  while ((idx = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, idx).replace(/\r$/, '');
    buf = buf.slice(idx + 1);
    if (!line) continue;
    if (process.env.FAKE_PI_LOG) {
      try { require('fs').appendFileSync(process.env.FAKE_PI_LOG, line + '\n'); } catch {}
    }
    let req;
    try { req = JSON.parse(line); } catch { continue; }
    handle(req, false);
  }
});

// Lifecycle log (FAKE_PI_LIFE_LOG): 'start <pid>' / 'exit <pid>' lines, so a
// test can count live processes (e.g. to catch an orphaned pi).
if (process.env.FAKE_PI_LIFE_LOG) {
  const life = (what) => {
    try { require('fs').appendFileSync(process.env.FAKE_PI_LIFE_LOG, `${what} ${process.pid}\n`); } catch {}
  };
  life('start');
  process.on('exit', () => life('exit'));
  process.on('SIGTERM', () => process.exit(0));
}

// FAKE_PI_QUEUE=1: behave like real pi for prompts sent while a turn is in
// flight - accept and queue them, run them after the current run's agent_end,
// and emit a single agent_settled once the queue has drained.
const QUEUE = process.env.FAKE_PI_QUEUE === '1';
let turnActive = false;
const pending = [];

// dequeued = true when a queued prompt starts (its response was already sent).
function handle(req, dequeued) {
    switch (req && req.type) {
      case 'prompt': {
        const m = (req.message || '').slice(0, 80);
        if (!dequeued && process.env.FAKE_PI_REJECT) {
          // Rejected before acceptance: no run starts, no agent_settled.
          emit({ id: req.id, type: 'response', command: 'prompt', success: false,
                 error: process.env.FAKE_PI_REJECT });
          break;
        }
        if (!dequeued) {
          emit({ id: req.id, type: 'response', command: 'prompt', success: true });
          if (QUEUE && turnActive) {
            pending.push(req);
            break;
          }
        }
        turnActive = true;
        const delay = parseInt(process.env.FAKE_PI_DELAY_MS || '150', 10);
        const turn  = parseInt(process.env.FAKE_PI_TURN_MS  || '150', 10);
        const tool  = process.env.FAKE_PI_TOOL || 'bash';
        const think = process.env.FAKE_PI_THINKING === '1';
        // FAKE_PI_THINKING_FILE: read the thinking text from a file (for huge
        // streams: Linux caps a single env string at 128KB, MAX_ARG_STRLEN).
        let thinkText = process.env.FAKE_PI_THINKING_TEXT || 'Thinking: weighing the options';
        if (process.env.FAKE_PI_THINKING_FILE) {
          try { thinkText = require('fs').readFileSync(process.env.FAKE_PI_THINKING_FILE, 'utf8'); } catch {}
        }
        const title = process.env.FAKE_PI_TITLE || 'pi';
        const prefix= process.env.FAKE_PI_REPLY_PREFIX || 'Echo: ';
        const editPath = process.env.FAKE_PI_EDIT_PATH || 'ctx.txt';
        const toolFail  = process.env.FAKE_PI_TOOLFAIL === '1';

        setTimeout(() => {
          emit({ type: 'agent_start' });
          // FAKE_PI_CRASH_MS=n: die n ms into the turn (no abort, no settle).
          const crash = parseInt(process.env.FAKE_PI_CRASH_MS || '0', 10);
          if (crash > 0) {
            setTimeout(() => process.exit(1), crash);
            return;
          }

          if (think) {
            emit({ type: 'message_start', message: { role: 'assistant' } });
            for (const c of thinkText) {
              emit({ type: 'message_update', assistantMessageEvent: { type: 'thinking_delta', delta: c } });
            }
            emit({ type: 'message_end', message: { role: 'assistant' } });
          }

          const trail = '\n'.repeat(parseInt(process.env.FAKE_PI_TRAILING_NEWLINES || '0', 10));
        const reply = `${prefix}${m}${trail}`;
          emit({ type: 'message_start', message: { role: 'assistant' } });
          // FAKE_PI_DELTAS='["a","\\n\\nb"]': stream exactly these text deltas
          // (default: one delta per character of the reply).
          const deltas = process.env.FAKE_PI_DELTAS ? JSON.parse(process.env.FAKE_PI_DELTAS) : [...reply];
          for (const c of deltas) {
            emit({ type: 'message_update', assistantMessageEvent: { type: 'text_delta', delta: c } });
          }
          emit({ type: 'message_update', assistantMessageEvent: { type: 'text_end', content: deltas.join('') } });
          emit({ type: 'message_end', message: { role: 'assistant' } });

          const tools = tool === 'multi' ? ['bash', 'read', 'edit'] : tool === 'none' ? [] : [tool];
          let i = 0;
          const runNext = () => {
            if (i >= tools.length) {
              finish();
              return;
            }
            const name = tools[i++];
            const bashCmd = process.env.FAKE_PI_BASH_CMD || 'echo fake';
            const args =
              name === 'bash' ? { command: bashCmd }
              : name === 'read' ? { path: editPath }
              : name === 'write' ? { path: editPath,
                  content: process.env.FAKE_PI_WRITE_CONTENT || 'alpha\nGAMMA\nbeta\nzeta\neta\ntheta\n' }
              : { path: editPath };
            emit({ type: 'tool_execution_start', toolName: name, args });
            setTimeout(() => {
              emit({ type: 'tool_execution_update', toolName: name, partialResult: name + ' output\n' });
              setTimeout(() => {
                if (name === 'write') {
                  // Behave like real pi: put the new content on disk before
                  // announcing the end, so the plugin's live reload has it.
                  require('fs').writeFileSync(editPath, args.content);
                }
                let cmdErr = false;
                if (name === 'bash' && process.env.FAKE_PI_BASH_CMD) {
                  // Same deal for bash: really run the command before
                  // announcing the end (the plugin can then reload any file
                  // it rewrote). A failing command is a tool error (like
                  // real pi), not a crash of the fake process.
                  try { require('child_process').execSync(bashCmd, { stdio: 'ignore' }); }
                  catch (e) { cmdErr = true; }
                }
                const end = { type: 'tool_execution_end', toolName: name, isError: (toolFail && name === tools[0]) || cmdErr };
                if (name === 'edit') {
                  // pi hands the TUI a pre-formatted display diff for edits.
                  end.result = { content: [{ type: 'text', text: 'ok' }],
                    details: { diff: process.env.FAKE_PI_DIFF || '   1 alpha\n-  2 beta\n+  2 gamma\n   3 delta',
                               firstChangedLine: 2 } };
                }
                if (process.env.FAKE_PI_TOOL_OUTPUT && !end.result) {
                  end.result = { content: [{ type: 'text', text: process.env.FAKE_PI_TOOL_OUTPUT }] };
                }
                emit(end);
                runNext();
              }, turn);
            }, turn);
          };
          if (process.env.FAKE_PI_PARALLEL) {
            // Two overlapping write calls (like pi running one assistant
            // message's tool calls in parallel): start A, start B, end A,
            // end B - each with its own toolCallId.
            const fs = require('fs');
            const calls = [
              { id: 'call_a', path: editPath, content: 'parallel-A\n' },
              { id: 'call_b', path: process.env.FAKE_PI_EDIT_PATH2 || 'ctx2.txt', content: 'parallel-B\n' },
            ];
            for (const c of calls) {
              emit({ type: 'tool_execution_start', toolCallId: c.id, toolName: 'write',
                     args: { path: c.path, content: c.content } });
            }
            setTimeout(() => {
              for (const c of calls) {
                fs.writeFileSync(c.path, c.content);
                emit({ type: 'tool_execution_end', toolCallId: c.id, toolName: 'write',
                       result: { content: [{ type: 'text', text: 'ok' }] }, isError: false });
              }
              finish();
            }, turn);
          } else if (tools.length) runNext(); else finish();

          function finish() {
            const ntype = process.env.FAKE_PI_NOTIFY_TYPE || '';
            const base = { type: 'extension_ui_request', id: 'ui-1', method: 'notify', title, message: `fake reply to: ${m}` };
            emit(ntype && ntype !== 'info' ? Object.assign({}, base, { notifyType: ntype }) : base);
            if (process.env.FAKE_PI_NOTIFY_ALL) {
              emit({ type: 'extension_ui_request', id: 'ui-2', method: 'notify', title, message: 'info note', notifyType: 'info' });
              emit({ type: 'extension_ui_request', id: 'ui-3', method: 'notify', title, message: 'warn note', notifyType: 'warning' });
              emit({ type: 'extension_ui_request', id: 'ui-4', method: 'notify', title, message: 'error note', notifyType: 'error' });
            }
            emit({ type: 'agent_end', willRetry: false });
            if (QUEUE && pending.length) {
              // A queued follow-up runs before pi settles.
              handle(pending.shift(), true);
              return;
            }
            turnActive = false;
            emit({ type: 'agent_settled' });
            const late = parseInt(process.env.FAKE_PI_LATE_NOTIFY_MS || '0', 10);
            if (late > 0) {
              setTimeout(() => {
                emit({ type: 'extension_ui_request', id: 'ui-late', method: 'notify', title, message: 'late note', notifyType: 'info' });
              }, late);
            }
          }
        }, delay);
        break;
      }
      case 'abort':
        emit({ id: req.id, type: 'response', command: 'abort', success: true });
        emit({ type: 'agent_end', willRetry: false });
        emit({ type: 'agent_settled' });
        break;
      case 'get_state':
        emit({ id: req.id, type: 'response', command: 'get_state', success: true,
               data: { model: FAKE_MODELS[fakeModelIdx] } });
        break;
      case 'get_available_models':
        emit({ id: req.id, type: 'response', command: 'get_available_models', success: true,
               data: { models: FAKE_MODELS } });
        break;
      case 'set_model': {
        const i = FAKE_MODELS.findIndex((m) => m.provider === req.provider && m.id === req.modelId);
        if (i < 0) {
          emit({ id: req.id, type: 'response', command: 'set_model', success: false,
                 error: `Model not found: ${req.provider}/${req.modelId}` });
        } else {
          fakeModelIdx = i;
          emit({ id: req.id, type: 'response', command: 'set_model', success: true, data: FAKE_MODELS[i] });
        }
        break;
      }
      case 'cycle_model':
        if (FAKE_MODELS.length <= 1) {
          emit({ id: req.id, type: 'response', command: 'cycle_model', success: true, data: null });
        } else {
          fakeModelIdx = (fakeModelIdx + 1) % FAKE_MODELS.length;
          emit({ id: req.id, type: 'response', command: 'cycle_model', success: true,
                 data: { model: FAKE_MODELS[fakeModelIdx], thinkingLevel: 'low', isScoped: false } });
        }
        break;
      case 'clear':
      case 'new_session':
      default:
        if (req && req.id != null) {
          emit({ id: req.id, type: 'response', command: req.type, success: true });
        }
        break;
    }
}
process.stdin.on('end', () => process.exit(0));

function emit(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}
