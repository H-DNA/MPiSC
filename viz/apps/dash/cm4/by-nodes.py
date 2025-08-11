import matplotlib.pyplot as plt
import os

# Create directory if it doesn't exist
os.makedirs("./cm4/by-nodes", exist_ok=True)

# Data from the measurements
nodes = [2, 3, 4]
patterns = ["all-to-all", "root", "scatter"]

# Performance data (in cycles or time units)
sopnop_data = {
    "all-to-all": [
        2.08914e06,
        2.21858e06,
        2.11778e06,
    ],
    "root": [
        6.29228e06,
        1.13489e07,
        1.75644e07,
    ],
    "scatter": [
        2.0045e06,
        2.08869e06,
        2.32464e06,
    ],
}

sq_data = {
    "all-to-all": [
        2.74057e06,
        4.89025e06,
        9.56704e06,
    ],
    "root": [
        6.04156e06,
        1.10507e07,
        1.91504e07,
    ],
    "scatter": [69344, 97756, 115981],
}

# Colors and styling
sopnop_color = "#2E86C1"
sq_color = "#E74C3C"

# Create separate plots for each pattern
for pattern in patterns:
    fig, ax = plt.subplots(1, 1, figsize=(15, 6))
    fig.suptitle(
        f"{pattern.upper()} Communication Pattern\n(100,000 messages, 1024 buffer size)",
        fontsize=16,
        fontweight="bold",
    )

    ax.plot(
        nodes,
        sopnop_data[pattern],
        marker="o",
        linewidth=3,
        markersize=10,
        label="AMQueue",
        color=sopnop_color,
    )
    ax.plot(
        nodes,
        sq_data[pattern],
        marker="s",
        linewidth=3,
        markersize=10,
        label="Bounded Slotqueue",
        color=sq_color,
    )

    ax.set_xlabel("Number of Nodes (x112 cores)", fontsize=12)
    ax.set_ylabel("Latency (us)", fontsize=12)
    ax.set_yscale("log")
    ax.set_xscale("log")
    ax.minorticks_off()
    ax.grid(True, alpha=0.3)
    ax.legend(fontsize=12)
    ax.set_xticks(nodes, [str(int(node)) for node in nodes], fontsize=12)

    # Save the plot
    filename = f"./cm4/by-nodes/{pattern}.png"
    plt.savefig(filename, dpi=300, bbox_inches="tight")
    print(f"Saved {filename}")
