// Run: node tests/dms-privacy.cjs <built-package>/share/quickshell/dms/Services/PrivacyService.qml
const assert = require("node:assert/strict");
const fs = require("node:fs");

const qml = fs.readFileSync(process.argv[2], "utf8");
const helper = qml.match(/function looksLikeSystemVirtualMic\(node\) \{([\s\S]*?)\n    \}/);
const indicator = qml.match(/readonly property bool microphoneActive: \{([\s\S]*?)\n    \}/);
assert.ok(helper, "virtual-mic helper must exist");
assert.ok(indicator, "microphone indicator must exist");
const exclude = new Function("node", helper[1]);
const active = new Function("Pipewire", "PwNodeType", "looksLikeSystemVirtualMic", indicator[1]);
const stream = (name, properties = {}) => ({ name, properties, type: 1, audio: { muted: false } });
const micActive = (...nodes) => active({ ready: true, nodes: { values: nodes } }, { AudioInStream: 1 }, exclude);

const sonar = stream("effect_input.sonar-micro-eq");
const discord = stream("WEBRTC VoiceEngine", {
    "application.name": "Discord",
    "target.object": "effect_output.sonar-micro-eq",
});
assert.equal(micActive(), false);
assert.equal(micActive(sonar), false);
assert.equal(micActive(stream("cava"), sonar), false);
assert.equal(micActive(discord), true);
assert.equal(micActive(sonar, discord), true);
assert.equal(micActive(discord, sonar), true);
assert.equal(micActive(stream("Firefox")), true);
assert.equal(micActive(stream("recorder", { "media.name": "Sonar Micro EQ" })), true);
assert.equal(micActive(stream("effect_input.sonar-micro-eq-other")), true);
assert.equal(micActive({ ...discord, audio: { muted: true } }, sonar), false);
assert.equal(exclude(null), false);
console.log("DMS privacy checks passed");
