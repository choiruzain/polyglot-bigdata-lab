MATCH (p:Product {id: 1})<-[:CONTAINS]-(:Order)-[:CONTAINS]->(other:Product) RETURN other.id AS product, other.name AS name, count(*) AS bought_together ORDER BY bought_together DESC, product LIMIT 5;
MATCH (c:Customer {id: 1})-[:PLACED]->(o:Order) RETURN count(o) AS orders;
SHOW SETTINGS YIELD name, value WHERE name STARTS WITH 'server.memory' RETURN name, value;
