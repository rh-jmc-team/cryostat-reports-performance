import sys, json

t = json.load(sys.stdin)
print(t["stats"][0]["total"]["summary"]["meanResponseTime"], end="")
print(" ", end="")
print(t["stats"][0]["total"]["summary"]["maxResponseTime"], end="")
print(" ", end="")
print(t["stats"][0]["total"]["summary"]["percentileResponseTime"]["50.0"], end="")
print(" ", end="")
print(t["stats"][0]["total"]["summary"]["percentileResponseTime"]["90.0"], end="")
print(" ", end="")
print(t["stats"][0]["total"]["summary"]["percentileResponseTime"]["99.0"], end="")
print(" ", end="")
print(t["info"]["errors"], end="")