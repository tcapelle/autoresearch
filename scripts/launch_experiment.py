#!/usr/bin/env python3
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "k8s" / "run-jobs.yaml"


def slugify(name: str) -> str:
    slug = name.lower()
    slug = re.sub(r"[^a-z0-9-]+", "-", slug)
    slug = re.sub(r"-{2,}", "-", slug).strip("-")
    if not slug:
        slug = "autoresearch"
    if len(slug) <= 50:
        return slug
    digest = hashlib.sha1(name.encode("utf-8")).hexdigest()[:8]
    return f"{slug[:41].rstrip('-')}-{digest}"


def parse_env_pairs(items: list[str]) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    for item in items:
        if "=" not in item:
            raise ValueError(f"Expected KEY=VALUE for --env, got {item!r}")
        key, value = item.split("=", 1)
        key = key.strip()
        if not re.fullmatch(r"[A-Z_][A-Z0-9_]*", key):
            raise ValueError(f"Invalid env var name {key!r}")
        pairs.append((key, value))
    return pairs


def render_manifest(
    job_name: str,
    run_name: str,
    branch: str,
    completions: int,
    parallelism: int,
    extra_env: list[tuple[str, str]],
) -> str:
    text = TEMPLATE.read_text()
    text = text.replace("name: autoresearch-train", f"name: {job_name}", 1)
    text = text.replace("completions: 2", f"completions: {completions}", 1)
    text = text.replace("parallelism: 2", f"parallelism: {parallelism}", 1)
    text = text.replace("codex/pai-git-jobs", branch)
    env_lines = [
        "            - name: WANDB_PROJECT\n"
        "              value: autoresearch",
        "            - name: WANDB_RUN_NAME\n"
        f"              value: {json.dumps(run_name)}",
    ]
    for key, value in extra_env:
        env_lines.append(
            "            - name: "
            f"{key}\n"
            f"              value: {json.dumps(value)}"
        )
    text = text.replace(
        "            - name: WANDB_PROJECT\n              value: autoresearch\n            # EXTRA_ENV",
        "\n".join(env_lines),
        1,
    )
    return text


def main() -> None:
    parser = argparse.ArgumentParser(description="Launch a named autoresearch training job on Kubernetes.")
    parser.add_argument("run_name", help="Human-readable experiment name for W&B.")
    parser.add_argument("--branch", required=True, help="Git branch to clone in the job.")
    parser.add_argument("--job-name", help="Kubernetes job name. Defaults to a slugified form of run_name.")
    parser.add_argument("--context", default="pai-amf1-cfd", help="kubectl context.")
    parser.add_argument("--completions", type=int, default=1, help="Job completions.")
    parser.add_argument("--parallelism", type=int, default=1, help="Job parallelism.")
    parser.add_argument("--env", action="append", default=[], help="Extra env var as KEY=VALUE. May be passed multiple times.")
    parser.add_argument("--output", help="Write the manifest here instead of /tmp/<job-name>.yaml.")
    parser.add_argument("--apply", action="store_true", help="Create the job with kubectl after writing the manifest.")
    args = parser.parse_args()
    extra_env = parse_env_pairs(args.env)

    job_name = args.job_name or slugify(args.run_name)
    manifest_path = Path(args.output) if args.output else Path("/tmp") / f"{job_name}.yaml"
    manifest = render_manifest(
        job_name=job_name,
        run_name=args.run_name,
        branch=args.branch,
        completions=args.completions,
        parallelism=args.parallelism,
        extra_env=extra_env,
    )
    manifest_path.write_text(manifest)
    print(manifest_path)

    if args.apply:
        subprocess.run(
            ["kubectl", "--context", args.context, "create", "-f", str(manifest_path)],
            check=True,
        )


if __name__ == "__main__":
    main()
