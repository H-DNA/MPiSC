import matplotlib.pyplot as plt
import os

output_dir = "cm4/all/by-nodes"
os.makedirs(output_dir, exist_ok=True)

nodes = [2, 3, 4]

queue_data = {
    "MPQueue": {
        "dequeue_throughput": [25.2825, 20.5676, 8.8967],
        "dequeue_latency": [0.39553, 0.486202, 1.12401],
        "enqueue_throughput": [16.8053, 13.8362, 14.5706],
        "enqueue_latency": [132.696, 242.118, 306.782],
        "total_throughput": [24.6331, 18.4367, 15.9835],
    },
    "Slotqueue": {
        "dequeue_throughput": [0.383657, 0.286227, 0.251241],
        "dequeue_latency": [26.065, 34.9373, 39.8024],
        "enqueue_throughput": [12.5555, 8.97462, 8.01345],
        "enqueue_latency": [177.611, 373.275, 557.812],
        "total_throughput": [0.767801, 0.572926, 0.502804],
    },
    "Slotqueue Node 2": {
        "dequeue_throughput": [0.26193, 0.182135, 0.142501],
        "dequeue_latency": [38.1782, 54.9044, 70.1751],
        "enqueue_throughput": [14.2978, 17.4061, 16.3308],
        "enqueue_latency": [155.968, 192.461, 273.717],
        "total_throughput": [0.524193, 0.36457, 0.285184],
    },
    "LTQueue": {
        "dequeue_throughput": [0.623893, 0.56184, 0.529911],
        "dequeue_latency": [16.0284, 17.7987, 18.8711],
        "enqueue_throughput": [10.8538, 7.85542, 6.05494],
        "enqueue_latency": [205.458, 426.457, 738.24],
        "total_throughput": [1.24858, 1.12461, 1.0605],
    },
    "Naive LTQueue Unbounded": {
        "dequeue_throughput": [0.122786, 0.0896213, 0.0768978],
        "dequeue_latency": [81.4426, 111.581, 130.043],
        "enqueue_throughput": [5.15652, 4.0541, 3.29228],
        "enqueue_latency": [432.462, 826.323, 1357.72],
        "total_throughput": [0.245728, 0.179391, 0.153894],
    },
    "AMQueue": {
        "dequeue_throughput": [3.07036, 2.4375, 2.15991],
        "dequeue_latency": [3.25694, 4.10257, 4.62982],
        "enqueue_throughput": [4.93226, 3.33835, 2.54221],
        "enqueue_latency": [452.126, 1003.49, 1758.31],
        "total_throughput": [6.05889, 4.7801, 3.93748],
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
    "MPQueue": {"color": "green", "marker": "^"},
    "Slotqueue": {"color": "blue", "marker": "o"},
    "Slotqueue Node 2": {"color": "cyan", "marker": "v"},
    "LTQueue": {"color": "red", "marker": "s"},
    "Naive LTQueue Unbounded": {"color": "orange", "marker": "x"},
    "AMQueue": {"color": "purple", "marker": "d"},
}

for metric in metrics:
    plt.figure(figsize=(12, 8))

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
    plt.legend(title="Queue Types", loc="best", fontsize=11)
    plt.xticks(nodes, [str(int(node)) for node in nodes], fontsize=12)
    plt.yticks(fontsize=12)
    plt.tight_layout()

    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename, dpi=300)
    plt.close()

print("All comparative plots have been generated in the 'cm4/all/by-nodes' folder.")
