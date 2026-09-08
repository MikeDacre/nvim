#!/usr/bin/env python3
"""mkalfred.py — build an .alfredworkflow from a small JSON spec.

  python3 scripts/mkalfred.py CLAUDE/alfred.json dist/tool.alfredworkflow

Spec (CLAUDE/alfred.json):
{
  "bundleid": "com.dacre.mytool",
  "name": "My Tool",
  "description": "…",
  "author": "Mike Dacre",
  "version": "0.1.0",
  "readme": "optional",
  "commands": [
    {"keyword": "mt-sync", "title": "Sync repo", "subtitle": "push all branches",
     "script": "cd /path/or/$repo && bash scripts/sync.sh auto",
     "with_arg": false, "notify": true}
  ]
}

Produces a real, importable workflow. Alfred will still let you rewire the
objects visually after import — this generates the scaffold, not the polish.
Alfred workflow object model: keyword input -> run-script action -> notification.
"""
import json
import os
import plistlib
import sys
import uuid
import zipfile

RUNSCRIPT = "alfred.workflow.action.script"
KEYWORD = "alfred.workflow.input.keyword"
NOTIFY = "alfred.workflow.output.notification"


def uid() -> str:
    return str(uuid.uuid4()).upper()


def build(spec: dict) -> dict:
    objects, ui, conns = [], {}, {}
    y = 60
    for cmd in spec["commands"]:
        k_uid, s_uid = uid(), uid()
        with_arg = bool(cmd.get("with_arg", False))
        objects.append({
            "type": KEYWORD, "uid": k_uid, "version": 1, "disabled": False,
            "config": {
                "argumenttype": 0 if with_arg else 2,
                "keyword": cmd["keyword"],
                "subtext": cmd.get("subtitle", ""),
                "text": cmd.get("title", cmd["keyword"]),
                "withspace": with_arg,
            },
        })
        objects.append({
            "type": RUNSCRIPT, "uid": s_uid, "version": 2, "disabled": False,
            "config": {
                "concurrently": False, "escaping": 102, "script": cmd["script"],
                "scriptargtype": 1 if with_arg else 0, "scriptfile": "",
                "type": 5,  # /bin/bash
            },
        })
        ui[k_uid] = {"xpos": 40, "ypos": y}
        ui[s_uid] = {"xpos": 300, "ypos": y}
        chain = [{"destinationuid": s_uid, "modifiers": 0,
                  "modifiersubtext": "", "vitoclose": False}]
        conns[k_uid] = chain
        if cmd.get("notify", True):
            n_uid = uid()
            objects.append({
                "type": NOTIFY, "uid": n_uid, "version": 1, "disabled": False,
                "config": {"lastpathcomponent": False, "onlyshowifquerypopulated": True,
                           "removeextension": False, "text": "{query}",
                           "title": cmd.get("title", spec.get("name", ""))},
            })
            ui[n_uid] = {"xpos": 560, "ypos": y}
            conns[s_uid] = [{"destinationuid": n_uid, "modifiers": 0,
                             "modifiersubtext": "", "vitoclose": False}]
        y += 140

    return {
        "bundleid": spec["bundleid"],
        "category": spec.get("category", "Tools"),
        "connections": conns,
        "createdby": spec.get("author", ""),
        "description": spec.get("description", ""),
        "disabled": False,
        "name": spec.get("name", spec["bundleid"]),
        "objects": objects,
        "readme": spec.get("readme", ""),
        "uidata": ui,
        "version": spec.get("version", "0.1.0"),
        "webaddress": spec.get("webaddress", ""),
    }


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    spec_path, out = sys.argv[1], sys.argv[2]
    with open(spec_path, encoding="utf-8") as fh:
        spec = json.load(fh)
    if not spec.get("commands"):
        sys.exit("spec has no commands")
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    plist = plistlib.dumps(build(spec))
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("info.plist", plist)
        if os.path.exists("assets/icon.png"):
            z.write("assets/icon.png", "icon.png")
    print(f"wrote {out} ({len(spec['commands'])} command(s)) — double-click to import")


if __name__ == "__main__":
    main()
