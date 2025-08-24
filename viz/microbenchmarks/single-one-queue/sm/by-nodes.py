import matplotlib.pyplot as plt
import os

output_dir = "sm/all/by-nodes"
os.makedirs(output_dir, exist_ok=True)
nodes = [2, 4, 8, 16]
queue_data = {
    "Slotqueue": {
        "dequeue_throughput": [0.604774, 0.427364, 0.379478, 0.0811423],
        "dequeue_latency": [16.5351, 23.3993, 26.352, 123.24],
        "enqueue_throughput": [7.83669, 5.66521, 4.30171, 0.0859294],
        "enqueue_latency": [121.225, 337.146, 890.345, 89259.4],
        "total_throughput": [1.21378, 0.859984, 0.771896, 0.147882],
    },
    "dLTQueue": {
        "dequeue_throughput": [0.615563, 0.539093, 0.467113, 0.0117279],
        "dequeue_latency": [16.2453, 18.5497, 21.4081, 852.666],
        "enqueue_throughput": [6.02576, 2.82674, 1.19098, 0.0101238],
        "enqueue_latency": [157.656, 675.691, 3215.85, 757619],
        "total_throughput": [1.23544, 1.08482, 0.950155, 0.0166181],
    },
    "AMQueue": {
        "dequeue_throughput": [1.66827, 1.29606, 0.658051, 0.020633],
        "dequeue_latency": [5.99425, 7.71566, 15.1964, 484.66],
        "enqueue_throughput": [2.83427, 1.56177, 0.29759, 0.0180177],
        "enqueue_latency": [335.183, 1222.97, 12870.1, 425693],
        "total_throughput": [3.17922, 2.35073, 0.420975, 0.0305976],
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
    plt.xlabel("Number of Nodes (x48 cores)", fontsize=14)
    plt.ylabel(f"{title} ({unit})", fontsize=14)
    plt.grid(True, alpha=0.3)
    plt.legend(title="Queue Types", loc="best", fontsize=12)
    plt.xticks(nodes, [str(int(node)) for node in nodes], fontsize=12)
    plt.yticks(fontsize=12)
    plt.tight_layout()
    filename = f"{output_dir}/{metric}_comparison.png"
    plt.savefig(filename, dpi=300)
    plt.close()
print("All comparative plots have been generated in the 'sm4/all/by-nodes' folder.")
