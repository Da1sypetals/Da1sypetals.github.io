import argparse

import numpy as np
import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
from matplotlib.colors import LogNorm


def sample_truncated_2d_normal(n, radius_limit, seed):
    rng = np.random.default_rng(seed)
    sigma = 1.0 / np.sqrt(2.0 * np.log(20.0))

    u = rng.random(n)
    theta = 2.0 * np.pi * rng.random(n)
    cdf_limit = 1.0 - np.exp(-(radius_limit**2) / (2.0 * sigma**2))
    r = sigma * np.sqrt(-2.0 * np.log1p(-u * cdf_limit))

    x = r * np.cos(theta)
    y = r * np.sin(theta)
    return x, y, sigma


def plot_heatmap(x, y, radius_limit, output_path, bins):
    heatmap, _, _ = np.histogram2d(
        x,
        y,
        bins=bins,
        range=[[-radius_limit, radius_limit], [-radius_limit, radius_limit]],
        density=True,
    )

    positive = heatmap[heatmap > 0]
    masked_heatmap = np.ma.masked_less_equal(heatmap.T, 0)

    cmap = plt.get_cmap("magma").copy()
    cmap.set_bad("black")

    fig, ax = plt.subplots(figsize=(7, 6), dpi=180)
    image = ax.imshow(
        masked_heatmap,
        origin="lower",
        extent=[-radius_limit, radius_limit, -radius_limit, radius_limit],
        cmap=cmap,
        norm=LogNorm(vmin=positive.min(), vmax=positive.max()),
        aspect="equal",
    )

    theta = np.linspace(0.0, 2.0 * np.pi, 512)
    ax.plot(np.cos(theta), np.sin(theta), color="cyan", linewidth=1.2, label="r = 1")
    ax.plot(
        radius_limit * np.cos(theta),
        radius_limit * np.sin(theta),
        color="white",
        linewidth=1.2,
        label=f"r = {radius_limit:g}",
    )

    fig.colorbar(image, ax=ax, label="density, log scale")
    ax.set_xlabel("x")
    ax.set_ylabel("y")
    ax.set_title("Truncated 2D Normal Heatmap, Log Scale")
    ax.legend()
    fig.tight_layout()
    fig.savefig(output_path)
    plt.close(fig)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=1_000_000)
    parser.add_argument("--radius-limit", type=float, default=1.125)
    parser.add_argument("--bins", type=int, default=240)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--output", default="truncated_normal_heatmap.png")
    args = parser.parse_args()

    x, y, sigma = sample_truncated_2d_normal(args.n, args.radius_limit, args.seed)
    norm = np.sqrt(x**2 + y**2)

    print(f"sigma = {sigma:.12f}")
    print(f"max norm = {norm.max():.12f}")
    print(f"P(norm <= 1) in truncated samples = {np.mean(norm <= 1.0):.12f}")

    plot_heatmap(x, y, args.radius_limit, args.output, args.bins)


if __name__ == "__main__":
    main()
