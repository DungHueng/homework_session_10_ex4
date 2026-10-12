```bash
#!/bin/bash
set -e

# Cau hinh PostgreSQL
DB_NAME="appdb"
DB_USER="appuser"
DB_PASSWORD="AppPass123"

echo "=== 1. Tao Custom Bridge Network ==="
docker network inspect app-net >/dev/null 2>&1 || \
    docker network create --driver bridge app-net

echo "=== 2. Tao Named Volume ==="
docker volume inspect db-data >/dev/null 2>&1 || \
    docker volume create db-data

echo "=== 3. Xoa container cu neu ton tai ==="
docker rm -f app-container db-server 2>/dev/null || true

echo "=== 4. Khoi chay PostgreSQL ==="
docker run -d \
    --name db-server \
    --network app-net \
    --network-alias db-server \
    -e POSTGRES_DB="$DB_NAME" \
    -e POSTGRES_USER="$DB_USER" \
    -e POSTGRES_PASSWORD="$DB_PASSWORD" \
    -v db-data:/var/lib/postgresql/data \
    postgres:15-alpine

echo "=== 5. Cho PostgreSQL san sang ==="
until docker exec db-server pg_isready -U "$DB_USER" -d "$DB_NAME"; do
    sleep 2
done

echo "=== 6. Khoi chay Backend ==="
docker run -d \
    --name app-container \
    --network app-net \
    -p 8081:3000 \
    -e DB_HOST=db-server \
    -e DB_PORT=5432 \
    -e DB_NAME="$DB_NAME" \
    -e DB_USER="$DB_USER" \
    -e DB_PASSWORD="$DB_PASSWORD" \
    --entrypoint sh \
    hw-backend:v1 \
    -c 'apk add --no-cache iputils >/dev/null && exec node server.js'

echo "=== 7. Kiem tra DNS va ket noi mang ==="
docker exec app-container ping -c 2 db-server

echo "=== 8. Tao bang va them du lieu thu nghiem ==="
docker exec -i db-server psql -U "$DB_USER" -d "$DB_NAME" <<'SQL'
CREATE TABLE IF NOT EXISTS persistence_test (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL
);
INSERT INTO persistence_test (message)
SELECT 'Du lieu van con sau khi tao lai container'
WHERE NOT EXISTS (
    SELECT 1 FROM persistence_test
    WHERE message = 'Du lieu van con sau khi tao lai container'
);
SELECT * FROM persistence_test;
SQL

echo "=== 9. Xoa cung container Database ==="
docker rm -f db-server

echo "=== 10. Tao lai Database voi cung Named Volume ==="
docker run -d \
    --name db-server \
    --network app-net \
    --network-alias db-server \
    -e POSTGRES_DB="$DB_NAME" \
    -e POSTGRES_USER="$DB_USER" \
    -e POSTGRES_PASSWORD="$DB_PASSWORD" \
    -v db-data:/var/lib/postgresql/data \
    postgres:15-alpine

echo "=== 11. Cho Database khoi dong lai ==="
until docker exec db-server pg_isready -U "$DB_USER" -d "$DB_NAME"; do
    sleep 2
done

echo "=== 12. Xac minh du lieu sau khi tao lai container ==="
docker exec db-server psql -U "$DB_USER" -d "$DB_NAME" \
    -c "SELECT * FROM persistence_test;"

echo "=== 13. Kiem tra Network va Volume ==="
docker network ls | grep app-net
docker volume ls | grep db-data
docker network inspect app-net

echo "=== 14. Kiem tra Backend API ==="
curl -i http://localhost:8081/

echo "=== HOAN THANH BAI 4 ==="
```