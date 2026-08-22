#!/usr/bin/env python3
"""Quantify final-present scaling from a source-surface and host screenshots.

The tool expects screenshots from the same frame. A sample is written as
LABEL,RECT_MODE,PATH where RECT_MODE is ``aspect`` (largest 16:9 fit) or
``integer`` (largest whole-number logical-pixel scale).

Example:
  python tests/analyze_scaling.py \
    --source /tmp/va11-nearest-surface-360-0.png \
    --sample nearest,aspect,/tmp/va11-nearest-host-360.png \
    --sample pixelart,aspect,/tmp/va11-pixelart-host-360.png \
    --sample integer,integer,/tmp/va11-integer-host-360.png
"""

from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image


@dataclass(frozen=True)
class Sample:
    label: str
    rect_mode: str
    path: Path


def parse_size(value: str) -> tuple[int, int]:
    try:
        width, height = (int(part) for part in value.lower().split("x", 1))
    except ValueError as exc:
        raise argparse.ArgumentTypeError("expected WIDTHxHEIGHT") from exc
    if width <= 0 or height <= 0:
        raise argparse.ArgumentTypeError("dimensions must be positive")
    return width, height


def parse_sample(value: str) -> Sample:
    try:
        label, rect_mode, path = value.split(",", 2)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("expected LABEL,aspect|integer,PATH") from exc
    if rect_mode not in {"aspect", "integer"}:
        raise argparse.ArgumentTypeError("rectangle mode must be aspect or integer")
    return Sample(label, rect_mode, Path(path))


def content_rect(
    image_width: int,
    image_height: int,
    grid_width: int,
    grid_height: int,
    mode: str,
) -> tuple[int, int, int, int]:
    if mode == "integer":
        scale = min(image_width // grid_width, image_height // grid_height)
        if scale >= 1:
            width = grid_width * scale
            height = grid_height * scale
        else:
            mode = "aspect"
    if mode == "aspect":
        # Mirror GLCommon_computeLetterbox: quantize to a multiple of the
        # reduced aspect unit so horizontal and vertical scales are equal.
        divisor = int(np.gcd(grid_width, grid_height))
        unit_width = grid_width // divisor
        unit_height = grid_height // divisor
        scale = min(image_width // unit_width, image_height // unit_height)
        width = unit_width * scale
        height = unit_height * scale
    x = (image_width - width) // 2
    y = (image_height - height) // 2
    return x, y, width, height


def nearest_prediction(source: np.ndarray, width: int, height: int) -> np.ndarray:
    source_height, source_width, _ = source.shape
    x = np.floor((np.arange(width) + 0.5) * source_width / width).astype(np.int32)
    y = np.floor((np.arange(height) + 0.5) * source_height / height).astype(np.int32)
    return source[y[:, None], x[None, :]]


def palette_membership(source: np.ndarray, target: np.ndarray) -> np.ndarray:
    source_codes = (
        (source[..., 0].astype(np.uint32) << 16)
        | (source[..., 1].astype(np.uint32) << 8)
        | source[..., 2].astype(np.uint32)
    )
    target_codes = (
        (target[..., 0].astype(np.uint32) << 16)
        | (target[..., 1].astype(np.uint32) << 8)
        | target[..., 2].astype(np.uint32)
    )
    return np.isin(target_codes, np.unique(source_codes))


def transition_histogram(
    logical: np.ndarray,
    target: np.ndarray,
    tolerance: int = 0,
) -> Counter[int]:
    """Count blended columns around clean horizontal logical-pixel boundaries."""
    logical_height, logical_width, _ = logical.shape
    target_height, target_width, _ = target.shape
    histogram: Counter[int] = Counter()

    # Sample only every fourth logical row/column; the screen contains tens of
    # thousands of clean edges, and subsampling keeps this developer check fast.
    for source_y in range(1, logical_height - 1, 4):
        target_y = min(
            target_height - 1,
            int((source_y + 0.5) * target_height / logical_height),
        )
        row = target[target_y].astype(np.int16)
        for source_x in range(1, logical_width - 1, 4):
            left = logical[source_y, source_x - 1].astype(np.int16)
            right = logical[source_y, source_x].astype(np.int16)
            if np.array_equal(left, right):
                continue

            boundary = source_x * target_width / logical_width
            lo = max(0, int(np.floor(boundary)) - 3)
            hi = min(target_width, int(np.ceil(boundary)) + 4)
            segment = row[lo:hi]
            is_left = np.max(np.abs(segment - left), axis=1) <= tolerance
            is_right = np.max(np.abs(segment - right), axis=1) <= tolerance
            mixed_positions = np.flatnonzero(~(is_left | is_right))
            if mixed_positions.size == 0:
                histogram[0] += 1
                continue

            # Count only the contiguous mixed run touching the mathematical
            # boundary, excluding unrelated detail farther away in the window.
            center = int(round(boundary)) - lo
            pivot = int(mixed_positions[np.argmin(np.abs(mixed_positions - center))])
            start = pivot
            end = pivot
            while start > 0 and not (is_left[start - 1] or is_right[start - 1]):
                start -= 1
            while end + 1 < len(segment) and not (is_left[end + 1] or is_right[end + 1]):
                end += 1
            histogram[end - start + 1] += 1
    return histogram


def isolated_run_histogram(logical: np.ndarray, target: np.ndarray) -> Counter[int]:
    """Measure solid run widths for isolated one-logical-pixel horizontal details."""
    logical_height, logical_width, _ = logical.shape
    target_height, target_width, _ = target.shape
    histogram: Counter[int] = Counter()
    for source_y in range(1, logical_height - 1, 4):
        target_y = min(
            target_height - 1,
            int((source_y + 0.5) * target_height / logical_height),
        )
        row = target[target_y]
        for source_x in range(1, logical_width - 1):
            color = logical[source_y, source_x]
            if np.array_equal(color, logical[source_y, source_x - 1]):
                continue
            if np.array_equal(color, logical[source_y, source_x + 1]):
                continue

            lo = max(0, int(np.floor(source_x * target_width / logical_width)) - 1)
            hi = min(
                target_width,
                int(np.ceil((source_x + 1) * target_width / logical_width)) + 1,
            )
            matches = np.all(row[lo:hi] == color, axis=1)
            longest = 0
            current = 0
            for match in matches:
                if match:
                    current += 1
                    longest = max(longest, current)
                else:
                    current = 0
            histogram[longest] += 1
    return histogram


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--flip-source", action="store_true")
    parser.add_argument("--grid", type=parse_size, default=(640, 360))
    parser.add_argument("--sample", action="append", type=parse_sample, required=True)
    args = parser.parse_args()

    source = np.asarray(Image.open(args.source).convert("RGB"))
    if args.flip_source:
        source = np.flipud(source)
    grid_width, grid_height = args.grid
    source_height, source_width, _ = source.shape
    if source_width % grid_width or source_height % grid_height:
        parser.error("source dimensions must be integer multiples of the logical grid")

    block_width = source_width // grid_width
    block_height = source_height // grid_height
    blocks = source.reshape(
        grid_height,
        block_height,
        grid_width,
        block_width,
        3,
    )
    logical = blocks[:, block_height // 2, :, block_width // 2]
    uniform_blocks = np.all(blocks == blocks[:, :1, :, :1, :], axis=(1, 3, 4))
    print(
        f"source={source_width}x{source_height} logical={grid_width}x{grid_height} "
        f"uniform_logical_blocks={uniform_blocks.mean() * 100:.3f}%"
    )

    for sample in args.sample:
        image = np.asarray(Image.open(sample.path).convert("RGB"))
        image_height, image_width, _ = image.shape
        x, y, width, height = content_rect(
            image_width,
            image_height,
            grid_width,
            grid_height,
            sample.rect_mode,
        )
        target = image[y : y + height, x : x + width]
        prediction = nearest_prediction(source, width, height)
        difference = np.abs(target.astype(np.int16) - prediction.astype(np.int16))
        exact = np.all(difference == 0, axis=2)
        in_palette = palette_membership(source, target)

        dx = np.abs(np.diff(target.astype(np.int16), axis=1)).max(axis=2)
        dy = np.abs(np.diff(target.astype(np.int16), axis=0)).max(axis=2)
        gradient_energy = (dx.mean() + dy.mean()) / 2.0
        transitions = transition_histogram(logical, target)
        runs = isolated_run_histogram(logical, target)
        transition_text = " ".join(
            f"{length}px:{count}" for length, count in sorted(transitions.items())
        )
        run_text = " ".join(
            f"{length}px:{count}" for length, count in sorted(runs.items())
        )
        print(
            f"{sample.label}: image={image_width}x{image_height} "
            f"viewport={width}x{height}+{x}+{y} logical_scale={width / grid_width:.6f}"
        )
        print(
            f"  nearest_exact={exact.mean() * 100:.4f}% "
            f"mae={difference.mean():.4f} max_error={difference.max()} "
            f"new_palette_pixels={(~in_palette).mean() * 100:.4f}% "
            f"gradient_energy={gradient_energy:.4f}"
        )
        print(f"  boundary_transition_histogram {transition_text}")
        print(f"  isolated_logical_pixel_run_histogram {run_text}")


if __name__ == "__main__":
    main()
