#!/usr/bin/env python3
"""
VidViz Engine - Shader Build Tool

GLSL → SPIR-V → Metal

- Android: GLSL source stays as-is (compiled at runtime with shaderc)
- iOS: GLSL → SPIR-V (using glslangValidator) → Metal (using SPIRV-Cross)

Usage:
    python build_shaders.py [--input INPUT_DIR] [--output OUTPUT_DIR] [--platform PLATFORM]
"""

import os
import sys
import argparse
import subprocess
import shutil
from pathlib import Path
from typing import Optional
import tempfile
import re


def find_tool(name: str) -> str:
    """Find a tool in PATH or common locations."""
    # Check PATH
    result = shutil.which(name)
    if result:
        return result
    
    # Check common locations
    common_paths = [
        f"/usr/local/bin/{name}",
        f"/opt/homebrew/bin/{name}",
        f"C:\\VulkanSDK\\1.3.275.0\\Bin\\{name}.exe",
        f"C:\\VulkanSDK\\1.3.250.0\\Bin\\{name}.exe",
    ]
    
    for path in common_paths:
        if os.path.exists(path):
            return path
    
    return None


def _read_text(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8")
    except Exception:
        return p.read_text()


def _write_text(p: Path, s: str) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(s, encoding="utf-8")


def _flutter_runtime_effect_stub() -> str:
    # Minimal subset needed by our shaders for offline compilation.
    # Most shaders only rely on FlutterFragCoord().
    return """// flutter/runtime_effect.glsl (stub for offline compilation)
vec4 FlutterFragCoord(){ return vec4(gl_FragCoord.xy, 0.0, 1.0); }
"""


def _expand_flutter_includes(src: str) -> str:
    # Replace Impeller runtime include with a local stub so glslangValidator can compile.
    # Shaders use the angle-bracket include form.
    return src.replace("#include <flutter/runtime_effect.glsl>", _flutter_runtime_effect_stub())


def _android_headerize_glsl(src: str) -> str:
    """Force GLES3-friendly header for Android outputs."""
    header = "#version 300 es\nprecision highp float;\n"

    # Remove leading BOM / whitespace and existing leading #version.
    s = src.lstrip("\ufeff")
    lines = s.splitlines(True)
    i = 0
    while i < len(lines) and lines[i].strip() == "":
        i += 1
    if i < len(lines) and lines[i].lstrip().startswith("#version"):
        i += 1
        # Drop immediate blank line after #version if present.
        if i < len(lines) and lines[i].strip() == "":
            i += 1
    body = "".join(lines[i:])
    return header + body


def _inject_vuv_glsl(src: str, stage: str) -> str:
    """Best-effort injection for shaders that reference vUV but forgot declarations.

    - Fragment: adds `in vec2 vUV;`
    - Vertex: adds `out vec2 vUV;` and assigns `vUV = aUV;` if possible
    """
    if "vUV" not in src:
        return src

    # If already declared, no-op.
    if re.search(
        r"(layout\s*\(\s*location\s*=\s*\d+\s*\)\s*)?\b(in|out|varying)\s+vec2\s+vUV\s*;",
        src,
    ):
        return src

    lines = src.splitlines(True)
    insert_at = 0
    # Insert after #version and #include block, if present.
    for i, line in enumerate(lines):
        tl = line.strip()
        if tl.startswith("#version") or tl.startswith("#include") or tl.startswith("#extension"):
            insert_at = i + 1
            continue
        # Keep blank lines immediately after header.
        if insert_at and tl == "":
            insert_at = i + 1
            continue
        if insert_at:
            break

    decl = ""
    if stage == "frag":
        decl = "layout(location = 0) in vec2 vUV;\n"
    elif stage == "vert":
        # Only inject declaration; assignment is handled by our generated vertex template.
        decl = "layout(location = 0) out vec2 vUV;\n"

    lines.insert(insert_at, decl)
    return "".join(lines)


def compile_glsl_to_spirv(
    input_path: str,
    output_path: str,
    stage: str = "frag",
    entry_point: Optional[str] = None,
    source_entrypoint: Optional[str] = None,
) -> bool:
    """Compile GLSL to SPIR-V using glslangValidator."""
    glslang = find_tool("glslangValidator")
    if not glslang:
        print(f"ERROR: glslangValidator not found. Install Vulkan SDK.")
        return False

    cmd = [
        glslang,
        "-V",  # Vulkan/SPIR-V target (does not require layout(location) for plain uniforms)
        "-S", stage,  # Shader stage (vert, frag, comp)
        "--auto-map-locations",  # Fill in missing layout(location=...)
        "--auto-map-bindings",  # Fill in missing bindings/locations for uniforms
    ]

    # Ensure SPIR-V has a deterministic entry point name (default varies across toolchains).
    if entry_point:
        cmd += ["-e", entry_point]

    _ = source_entrypoint

    cmd += [
        "-o", output_path,
        input_path,
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"ERROR compiling {input_path}:")
            if result.stdout:
                print(result.stdout)
            if result.stderr:
                print(result.stderr)
            return False
        return True
    except Exception as e:
        print(f"ERROR: {e}")
        return False


def _rename_spirv_cross_main0(msl: str, stage: str) -> str:
    # spirv-cross tends to generate `main0` and related structs like `main0_in/main0_out`.
    # Since we merge vertex+fragment MSL into a single .metal file, we must avoid
    # symbol collisions.
    if "main0" not in msl:
        return msl

    if stage == "vert":
        fn = "vmain"
        prefix = "vv_vmain"
    else:
        fn = "fmain"
        prefix = "vv_fmain"

    # Replace longer tokens first.
    repl = [
        (r"\bmain0_out\b", f"{prefix}_out"),
        (r"\bmain0_in\b", f"{prefix}_in"),
        (r"\bmain0\b", fn),
    ]
    out = msl
    for pat, rpl in repl:
        out = re.sub(pat, rpl, out)
    return out


def _strip_msl_prelude(msl: str) -> str:
    """Make merged MSL cleaner by stripping duplicate headers from spirv-cross output."""
    out_lines = []
    for line in msl.splitlines():
        tl = line.strip()
        if tl.startswith("#include <metal_stdlib>"):
            continue
        if tl.startswith("using namespace metal"):
            continue
        out_lines.append(line)
    return "\n".join(out_lines).strip() + "\n"


def _default_vertex_glsl() -> str:
    # Vertex template that matches Android's assumptions (vUV) and draws a fullscreen quad.
    # We keep this minimal and compatible with glslang.
    return """#version 450

layout(location = 0) in vec2 aPos;
layout(location = 1) in vec2 aUV;

layout(location = 0) out vec2 vUV;

void main() {
    vUV = aUV;
    gl_Position = vec4(aPos, 0.0, 1.0);
}
"""


def _rename_glsl_entrypoint(src: str, new_name: str) -> str:
    # Best-effort rename of `void main(` to `void <new_name>(`.
    return re.sub(r"\bvoid\s+main\s*\(", f"void {new_name}(", src, count=1)


def _ensure_fragcolor_location(src: str) -> str:
    # Vulkan/OpenGL SPIR-V requires explicit locations for user outputs.
    if "fragColor" not in src:
        return src
    if re.search(r"layout\s*\(\s*location\s*=\s*\d+\s*\)\s*out\s+vec4\s+fragColor\s*;", src):
        return src
    return re.sub(r"\bout\s+vec4\s+fragColor\s*;", "layout(location = 0) out vec4 fragColor;", src, count=1)


def _normalize_glsl_for_vulkan(src: str) -> str:
    # Vulkan GLSL expects a single '#version 450' directive at the top (no profile like 'core').
    # Some of our sources include comments before #version or even multiple #version lines.
    lines = src.lstrip("\ufeff").splitlines(True)

    # Find first #version line.
    first_ver = None
    for i, line in enumerate(lines):
        tl = line.lstrip()
        if tl.startswith("#version"):
            first_ver = i
            break

    out: list[str] = []
    out.append("#version 450\n")

    def _is_version_line(line: str) -> bool:
        return line.lstrip().startswith("#version")

    if first_ver is None:
        # No version directive found; drop leading trivia and just prepend the version.
        for line in lines:
            if _is_version_line(line):
                continue
            out.append(line)
        return "".join(out)

    # Drop anything before the first #version to guarantee the version directive is first.
    # Then skip ALL version lines and keep everything else.
    for line in lines[first_ver + 1 :]:
        if _is_version_line(line):
            continue
        out.append(line)
    return "".join(out)


def _wrap_nonopaque_uniforms_into_ubo(src: str) -> str:
    # Vulkan GLSL disallows non-opaque uniforms outside blocks.
    # We move scalar/vector/matrix uniform declarations into a std140 UBO.
    lines = src.splitlines(True)
    uniform_members: list[str] = []
    out_lines: list[str] = []

    uniform_re = re.compile(
        r"^\s*uniform\s+(?!sampler|texture|image|subpassInput)"
        r"([A-Za-z_][A-Za-z0-9_]*)\s+"
        r"([A-Za-z_][A-Za-z0-9_]*)"
        r"(\s*\[[^\]]+\])?\s*;\s*(?://.*)?$"
    )

    for line in lines:
        m = uniform_re.match(line)
        if m:
            utype = m.group(1)
            uname = m.group(2)
            uarr = m.group(3) or ""
            uniform_members.append(f"    {utype} {uname}{uarr};\n")
            continue
        out_lines.append(line)

    if not uniform_members:
        return "".join(out_lines)

    # Insert block after preprocessor header region.
    insert_at = 0
    while insert_at < len(out_lines):
        tl = out_lines[insert_at].strip()
        if tl.startswith("#") or tl == "":
            insert_at += 1
            continue
        break

    block = [
        "layout(set = 0, binding = 0, std140) uniform VVUniforms {\n",
        *uniform_members,
        "};\n",
    ]

    out_lines[insert_at:insert_at] = block
    return "".join(out_lines)


def _explode_uniform_declarations(src: str) -> str:
    # Normalize `uniform ...; uniform ...;` into one declaration per line.
    # Keeps semantics but makes our UBO wrapper simpler.
    return re.sub(r";\s*uniform\s+", ";\nuniform ", src)


def compile_spirv_to_metal(
    input_path: str,
    output_path: str,
    stage: str,
    entry_point: str,
) -> bool:
    """Convert SPIR-V to Metal using SPIRV-Cross."""
    spirv_cross = find_tool("spirv-cross")
    if not spirv_cross:
        print(f"ERROR: spirv-cross not found. Install via: brew install spirv-cross")
        return False
    
    _ = stage
    _ = entry_point

    # NOTE: spirv-cross expects the SPIR-V file as the first positional argument.
    # We intentionally avoid passing stage/entry flags here since some spirv-cross
    # builds do not support them and still emit correct MSL for single-entry SPIR-V.
    cmd = [
        spirv_cross,
        input_path,
        "--msl",  # Metal Shading Language output
        "--msl-version",
        "20100",  # Metal 2.1
        "--output",
        output_path,
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"ERROR converting {input_path} to Metal:")
            if result.stdout:
                print(result.stdout)
            if result.stderr:
                print(result.stderr)
            return False
        return True
    except Exception as e:
        print(f"ERROR: {e}")
        return False


def process_shader(input_path: Path, input_dir: Path, output_dir: Path, platform: str, inject_vuv: bool) -> bool:
    """Process a single shader file."""
    name = input_path.stem
    try:
        rel = input_path.relative_to(input_dir)
    except Exception:
        rel = Path(input_path.name)

    # Determine shader stage from extension or name
    if input_path.suffix == ".vert" or "vert" in name.lower():
        stage = "vert"
    elif input_path.suffix == ".comp" or "comp" in name.lower():
        stage = "comp"
    else:
        stage = "frag"

    print(f"Processing: {rel}")

    raw_src = _read_text(input_path)

    # Always emit Android GLSL (a straight copy + optional vUV decl injection).
    if platform in ("android", "all"):
        android_out = (output_dir / "android" / rel).with_suffix(".glsl")
        a_src = _inject_vuv_glsl(raw_src, stage) if inject_vuv else raw_src
        a_src = _android_headerize_glsl(a_src)
        _write_text(android_out, a_src)

    if platform not in ("ios", "all"):
        return True

    # iOS: GLSL frag + generated GLSL vertex -> SPIR-V -> MSL -> merged .metal
    if stage != "frag":
        # For now we only convert fragment shaders to MSL (engine expects fragment-only shader IDs).
        return True

    ios_out = (output_dir / "ios" / rel).with_suffix(".metal")

    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)

        v_glsl_path = td_path / f"{name}.vert.glsl"
        f_glsl_path = td_path / f"{name}.frag.glsl"
        v_spv_path = td_path / f"{name}.vert.spv"
        f_spv_path = td_path / f"{name}.frag.spv"
        v_msl_path = td_path / f"{name}.vert.metal"
        f_msl_path = td_path / f"{name}.frag.metal"

        v_src = _default_vertex_glsl()
        f_src = _expand_flutter_includes(raw_src)
        f_src = _normalize_glsl_for_vulkan(f_src)

        # Some shaders in the repo are Shadertoy-style (mainImage/iResolution/iTime) and
        # are not compatible with our Impeller-style pipeline. We still emit Android GLSL,
        # but skip iOS offline compilation for these.
        if not re.search(r"\bvoid\s+main\s*\(", f_src):
            print(f"Skipping iOS compile (no main()): {rel}")
            return True

        f_src = _explode_uniform_declarations(f_src)
        f_src = _ensure_fragcolor_location(f_src)
        if inject_vuv:
            # Default vertex already declares vUV; avoid re-injecting.
            f_src = _inject_vuv_glsl(f_src, "frag")

        f_src = _wrap_nonopaque_uniforms_into_ubo(f_src)

        _write_text(v_glsl_path, v_src)
        _write_text(f_glsl_path, f_src)

        if not compile_glsl_to_spirv(
            str(v_glsl_path),
            str(v_spv_path),
            "vert",
            entry_point="main",
        ):
            return False
        if not compile_glsl_to_spirv(
            str(f_glsl_path),
            str(f_spv_path),
            "frag",
            entry_point="main",
        ):
            return False

        if not compile_spirv_to_metal(str(v_spv_path), str(v_msl_path), "vert", entry_point="main"):
            return False
        if not compile_spirv_to_metal(str(f_spv_path), str(f_msl_path), "frag", entry_point="main"):
            return False

        v_msl = _strip_msl_prelude(_rename_spirv_cross_main0(_read_text(v_msl_path), "vert"))
        f_msl = _strip_msl_prelude(_rename_spirv_cross_main0(_read_text(f_msl_path), "frag"))

        merged = "#include <metal_stdlib>\nusing namespace metal;\n\n" + v_msl + "\n" + f_msl
        _write_text(ios_out, merged)
        return True


def main():
    parser = argparse.ArgumentParser(description="VidViz Shader Build Tool")
    parser.add_argument("--input", "-i", default="assets/raw_shaders", help="Input directory with GLSL files")
    parser.add_argument("--output", "-o", default="assets/native", help="Output directory")
    parser.add_argument("--platform", "-p", choices=["android", "ios", "all"], default="all", help="Target platform")
    vuv_group = parser.add_mutually_exclusive_group()
    vuv_group.add_argument("--inject-vuv", dest="inject_vuv", action="store_true", help="Inject vUV varying when referenced")
    vuv_group.add_argument("--no-inject-vuv", dest="inject_vuv", action="store_false", help="Disable vUV injection")
    parser.set_defaults(inject_vuv=True)
    
    args = parser.parse_args()
    
    input_dir = Path(args.input)
    output_dir = Path(args.output)
    
    if not input_dir.exists():
        print(f"ERROR: Input directory does not exist: {input_dir}")
        return 1
    
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Find all shader files
    shader_extensions = [".frag", ".vert", ".comp", ".glsl"]
    shader_files = []
    
    for ext in shader_extensions:
        shader_files.extend(input_dir.rglob(f"*{ext}"))
    
    if not shader_files:
        print(f"No shader files found in {input_dir}")
        return 1
    
    print(f"Found {len(shader_files)} shader files")
    print(f"Platform: {args.platform}")
    print(f"Output: {output_dir}")
    print("-" * 40)
    
    success_count = 0
    fail_count = 0
    
    for shader_path in shader_files:
        if process_shader(shader_path, input_dir, output_dir, args.platform, args.inject_vuv):
            success_count += 1
        else:
            fail_count += 1
    
    print("-" * 40)
    print(f"Done! Success: {success_count}, Failed: {fail_count}")
    
    return 0 if fail_count == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
