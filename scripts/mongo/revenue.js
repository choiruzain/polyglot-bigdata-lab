db = db.getSiblingDB("shop");
const base = [
  { $match: { status: "delivered" } },
  { $unwind: "$items" },
  { $lookup: { from: "products", localField: "items.product_id", foreignField: "_id", as: "p" } },
  { $unwind: "$p" }
];
print("--- revenue by category");
db.orders.aggregate(base.concat([
  { $group: { _id: "$p.category", revenue: { $sum: { $multiply: ["$items.quantity", "$p.price"] } } } },
  { $project: { _id: 0, category: "$_id", revenue: { $round: ["$revenue", 2] } } },
  { $sort: { category: 1 } }
])).forEach(d => print(d.category, d.revenue.toString()));
print("--- total");
db.orders.aggregate(base.concat([
  { $group: { _id: null, total: { $sum: { $multiply: ["$items.quantity", "$p.price"] } } } }
])).forEach(d => print("TOTAL", d.total.toString()));
