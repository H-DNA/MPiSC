import matplotlib.pyplot as plt
import os

output_dir = "cm4/all/by-nodes"
os.makedirs(output_dir, exist_ok=True)

nodes = [2, 3, 4]

queue_data = {
    "Slotqueue": {
        "dequeue_throughput": [0.386877, 0.305279, 0.29129],
        "dequeue_latency": [25.848, 32.7569, 34.33],
        "enqueue_throughput": [9.45739, 6.99411, 5.76632],
        "enqueue_latency": [235.794, 478.974, 775.191],
        "total_throughput": [0.775107, 0.612084, 0.590766],
    },
    "dLTQueue": {
        "dequeue_throughput": [0.613655, 0.555507, 0.511682],
        "dequeue_latency": [16.2958, 18.0016, 19.5434],
        "enqueue_throughput": [5.33484, 2.70814, 1.56644],
        "enqueue_latency": [418.007, 1237.01, 2853.6],
        "total_throughput": [1.22946, 1.11379, 1.03774],
    },
    "AMQueue": {
        "dequeue_throughput": [3.16927, 2.98791, 2.51888],
        "dequeue_latency": [3.1553, 3.34682, 3.97002],
        "enqueue_throughput": [4.63649, 3.52094, 2.34645],
        "enqueue_latency": [480.968, 951.45, 1905],
        "total_throughput": [5.63325, 4.88797, 3.51556],
    },
}

metrics = [
    "dequeue_throughput",
    "dequeue_latency",
    "enqueue_throughput",
    "enqueue_latency",
    "total_throughput",
]

metric_labels = {
    "dequeue_throughput": ("Dequeue Throughput", "10^5 ops/s"),
    "dequeue_latency": ("Dequeue Latency", "μs"),
    "enqueue_throughput": ("Enqueue Throughput", "10^5 ops/s"),
    "enqueue_latency": ("Enqueue Latency", "μs"),
    "total_throughput": ("Total Throughput", "10^5 ops/s"),
}

queue_styles = {
    "Slotqueue": {"color": "blue", "marker": "o"},
    "dLTQueue": {"color": "red", "marker": "s"},
    "AMQueue": {"color": "purple", "marker": "d"},
}

for metric in metrics:
    plt.figure(figsize=(12, 7))

    for queue_name, queue_metrics in queue_data.items():
        style = queue_styles[queue_name]
        linestyle = style.get("linestyle", "-")

        plt.plot(
            nodes,
            queue_metrics[metric],
            color=style["color"],
            marker=style["marker"],
            linestyle=linestyle,
            label=queue_name,
            linewidth=2,
            markersize=8,
        )

    title, unit = metric_labels[metric]
    plt.title(f"Comparative {title} Across Queue Implementations", fontsize=16)
    plt.xlabel("Number of Nodes (x112 cores)", fontsize=14)
    plt.ylabel(f"{title} ({unit})", fontsize=14)
    plt.grid(True, alpha=0.3)
    plt.legend(title="Queue Types", loc="best", fontsize=12)
    plt.xticks(nodes, [str(int(node)) for node in nodes], fontsize=12)
    plt.yticks(fontsize=12)
    plt.tight_layout()

    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename, dpi=300)
    plt.close()

print("All comparative plots have been generated in the 'cm4/all/by-nodes' folder.")
