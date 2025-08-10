import matplotlib.pyplot as plt
import os

output_dir = "cm4/all/by-nodes"
os.makedirs(output_dir, exist_ok=True)

nodes = [2, 3, 4]

queue_data = {
    "Slotqueue": {
        "dequeue_throughput": [0.0174704, 0.0114833, 0.00932901],
        "dequeue_latency": [572.395, 870.83, 1071.93],
        "enqueue_throughput": [0.0575015, 0.0422524, 0.0344312],
        "enqueue_latency": [38781.6, 79285.4, 129824],
        "total_throughput": [0.035002, 0.023024, 0.0189202],
    },
    "LTQueue": {
        "dequeue_throughput": [0.0136667, 0.0118626, 0.0105236],
        "dequeue_latency": [731.705, 842.988, 950.244],
        "enqueue_throughput": [0.0331294, 0.0165126, 0.0108748],
        "enqueue_latency": [67311.8, 202875, 411043],
        "total_throughput": [0.0273813, 0.0237844, 0.0194079],
    },
    "AMQueue": {
        "dequeue_throughput": [0.0634113, 0.0507263, 0.039581],
        "dequeue_latency": [157.701, 197.137, 252.647],
        "enqueue_throughput": [0.0574075, 0.0415926, 0.0283861],
        "enqueue_latency": [38845.1, 80543.3, 157471],
        "total_throughput": [0.102263, 0.0731421, 0.0500319],
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
    "LTQueue": {"color": "red", "marker": "s"},
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

print(
    "All comparative plots have been generated in the 'cm4/all/by-nodes' folder."
)
