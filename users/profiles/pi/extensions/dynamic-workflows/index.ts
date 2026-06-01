import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import {
  createWorkflowStorage,
  createWorkflowTool,
  initProfiler,
  installAutoWorkflow,
  installResultDelivery,
  installTaskPanel,
  installWorkflowEditor,
  registerAllSavedWorkflows,
  registerBuiltinWorkflows,
  registerWorkflowCommands,
  WorkflowManager,
} from "./src/index.ts";

export default function extension(pi: ExtensionAPI) {
  // Single manager/storage shared by the workflow tool and the /workflows command,
  // so background runs started by the tool are reachable from the command.
  const cwd = process.cwd();
  // Opt-in freeze diagnostics: `PI_WF_PROFILE=1 pi` logs event-loop stalls and
  // slow sections to .pi/workflows/profile.log. No-op when unset.
  initProfiler(cwd);
  const storage = createWorkflowStorage(cwd);
  const manager = new WorkflowManager({ cwd, loadSavedWorkflow: (name) => storage.load(name)?.script });

  const workflowTool = createWorkflowTool({ cwd, manager, storage });
  pi.registerTool(workflowTool);
  registerWorkflowCommands(pi, manager, { storage, cwd });
  registerBuiltinWorkflows(pi, { cwd });
  registerAllSavedWorkflows(pi, cwd, storage);
  // Deliver a background run's result into the conversation when it finishes.
  installResultDelivery(pi, manager);
  // Opt-in auto-workflow toggle (`/auto-workflow off|suggest|force`, default off).
  // Returns a controller the workflows-mode input hook consults each submit.
  const auto = installAutoWorkflow(pi);
  // "Workflows mode": type `workflow(s)` to arm a forced workflow (animated),
  // Backspace right after the word disarms it. Registers the `input` hook now;
  // the editor itself is installed once the UI is available (session_start).
  let editorInstalled = false;
  let taskPanelInstalled = false;

  pi.on("session_start", (_event: unknown, ctx: ExtensionContext) => {
    const active = pi.getActiveTools();
    if (!active.includes(workflowTool.name)) {
      pi.setActiveTools([...active, workflowTool.name]);
    }
    // Tell the manager the session's main model so "explore" agents auto-tier
    // down to a lighter same-family sibling (e.g. Claude → Haiku).
    manager.setMainModel(ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : undefined);
    // Live "workflows running" panel below the input. Install once (like the
    // editor) so we don't re-register the widget + manager listeners each session.
    if (!taskPanelInstalled) {
      installTaskPanel(pi, manager, ctx.ui, { storage, cwd });
      taskPanelInstalled = true;
    }
    if (!editorInstalled) {
      installWorkflowEditor(pi, ctx.ui, { auto });
      editorInstalled = true;
    }
  });
}
