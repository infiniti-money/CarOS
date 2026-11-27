"""Create and verify local APK manifests. Never installs or deletes apps."""
import argparse
import hashlib
import json
import re
from pathlib import Path

SHA = re.compile(r"[0-9a-f]{40}")
DIGEST = re.compile(r"[0-9a-f]{64}")
VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")
PACKAGE = "com.infinitimoney.infiniti_caros"
FIELDS = {"schema", "package", "version", "build", "commit", "artifact", "bytes", "sha256", "channel"}

def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()

def version_from_pubspec(path):
    matches = re.findall(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$", path.read_text(), re.M)
    if len(matches) != 1:
        raise ValueError("Expected one version: X.Y.Z+build")
    version, build = matches[0]
    return version, int(build)

def validate(data):
    if not isinstance(data, dict) or set(data) != FIELDS:
        raise ValueError("Invalid manifest fields")
    if type(data["schema"]) is not int or data["schema"] != 1 or data["package"] != PACKAGE:
        raise ValueError("Wrong schema or application")
    if not isinstance(data["version"], str) or not VERSION.fullmatch(data["version"]):
        raise ValueError("Invalid version")
    if type(data["build"]) is not int or not 1 <= data["build"] <= 2100000000:
        raise ValueError("Invalid build number")
    if not isinstance(data["commit"], str) or not SHA.fullmatch(data["commit"]):
        raise ValueError("Invalid commit")
    if not isinstance(data["sha256"], str) or not DIGEST.fullmatch(data["sha256"]):
        raise ValueError("Invalid checksum")
    if type(data["bytes"]) is not int or data["bytes"] <= 0:
        raise ValueError("Invalid file size")
    name = data["artifact"]
    if not isinstance(name, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}\.apk", name):
        raise ValueError("Unsafe artifact name")
    if data["channel"] != "debug":
        raise ValueError("Only debug CI artifacts supported")
    return data

def create(apk, pubspec, commit):
    version, build = version_from_pubspec(pubspec)
    return validate({"schema": 1, "package": PACKAGE, "version": version, "build": build,
        "commit": commit, "artifact": apk.name, "bytes": apk.stat().st_size,
        "sha256": digest(apk), "channel": "debug"})

def load_manifest(path):
    if path.stat().st_size > 16384:
        raise ValueError("Manifest too large")
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("Duplicate manifest key")
            result[key] = value
        return result
    return validate(json.loads(path.read_text(), object_pairs_hook=unique))

def verify(apk, data):
    validate(data)
    if apk.name != data["artifact"] or apk.stat().st_size != data["bytes"] or digest(apk) != data["sha256"]:
        raise ValueError("APK name, size or SHA-256 mismatch")
    return data

def rollback_plan(current, candidate):
    validate(current)
    validate(candidate)
    if candidate["build"] >= current["build"]:
        raise ValueError("Rollback needs a strictly older build")
    if candidate["commit"] == current["commit"]:
        raise ValueError("Rollback must target a different commit")
    return {"from_build": current["build"], "to_build": candidate["build"],
        "target_commit": candidate["commit"], "sha256": candidate["sha256"],
        "install_allowed": False,
        "required": ["Confirm trusted CI provenance independently", "Verify package, version and signing certificate with Android SDK tools",
            "Back up supported app data", "Check Android downgrade and data-schema compatibility",
            "Use a signed forward-fix if downgrade is blocked; do not uninstall automatically"]}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    make = commands.add_parser("create")
    make.add_argument("--apk", type=Path, required=True)
    make.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    make.add_argument("--commit", required=True)
    make.add_argument("--output", type=Path, required=True)
    check = commands.add_parser("verify")
    check.add_argument("--apk", type=Path, required=True)
    check.add_argument("--manifest", type=Path, required=True)
    plan = commands.add_parser("rollback-plan")
    plan.add_argument("--current", type=Path, required=True)
    plan.add_argument("--candidate", type=Path, required=True)
    plan.add_argument("--apk", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "create":
            data = create(args.apk, args.pubspec, args.commit)
            with args.output.open("x", encoding="utf-8") as stream:
                json.dump(data, stream, indent=2, sort_keys=True)
                stream.write("\n")
        elif args.command == "verify":
            data = verify(args.apk, load_manifest(args.manifest))
            print(json.dumps({"integrity": "verified", "sha256": data["sha256"], "authenticity": "not verified"}, indent=2))
        else:
            candidate = verify(args.apk, load_manifest(args.candidate))
            print(json.dumps(rollback_plan(load_manifest(args.current), candidate), indent=2))
    except (ValueError, OSError) as error:
        parser.exit(1, f"Verification refused: {error}\n")

if __name__ == "__main__":
    main()
