# Bài 4 – Custom Network & Named Volume bằng Docker CLI

## 1. Mục tiêu

- Tạo Custom Bridge Network có tên `app-net`.
- Tạo Named Volume `db-data` để lưu trữ dữ liệu PostgreSQL bền vững.
- Kết nối Backend Container với PostgreSQL Container thông qua Docker DNS.
- Kiểm tra khả năng duy trì dữ liệu khi xóa và tạo lại Database Container.

## 2. Công nghệ sử dụng

- Docker CLI
- Docker Bridge Network
- Docker Named Volume
- Node.js Backend API
- PostgreSQL 15 Alpine

## 3. Cấu hình hệ thống

| Thành phần | Giá trị |
|---|---|
| Network | `app-net` |
| Network Driver | `bridge` |
| Named Volume | `db-data` |
| Backend Container | `app-container` |
| Database Container | `db-server` |
| Database | `appdb` |
| Database Host | `db-server` |
| Database Port | `5432` |
| PostgreSQL Image | `postgres:15-alpine` |

## 4. Tạo Custom Bridge Network

Thực hiện lệnh sau để tạo mạng riêng cho các container:

```bash
docker network create app-net
```

Kiểm tra Network:

```bash
docker network ls
```

Kiểm tra thông tin chi tiết:

```bash
docker network inspect app-net
```

**Kết quả mong đợi:** Network `app-net` được tạo thành công với driver `bridge`.

## 5. Tạo Named Volume

Tạo volume để lưu trữ dữ liệu PostgreSQL:

```bash
docker volume create db-data
```

Kiểm tra danh sách volume:

```bash
docker volume ls
```

Kiểm tra thông tin chi tiết:

```bash
docker volume inspect db-data
```

**Kết quả mong đợi:** Volume `db-data` được tạo thành công và sẵn sàng sử dụng.

## 6. Khởi chạy PostgreSQL Container

Khởi chạy PostgreSQL 15 Alpine, kết nối với Network `app-net` và gắn Named Volume `db-data` vào thư mục dữ liệu của PostgreSQL.

```bash
docker run -d \
  --name db-server \
  --network app-net \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=app123 \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine
```

Kiểm tra container:

```bash
docker ps
```

Kiểm tra log khởi động:

```bash
docker logs db-server
```

Kiểm tra kết nối PostgreSQL:

```bash
docker exec db-server pg_isready -U appuser -d appdb
```

**Kết quả mong đợi:** PostgreSQL khởi động thành công và sẵn sàng nhận kết nối.

> Lưu ý: Mật khẩu trong ví dụ chỉ phục vụ bài thực hành. Không sử dụng mật khẩu này trong môi trường thực tế.

## 7. Kết nối Backend với PostgreSQL

Backend Container cần được kết nối vào cùng Network `app-net` để truy cập Database Container thông qua Docker DNS.

Ví dụ, nếu Backend Image đã được build với tên `hw-backend:v1`, có thể chạy Backend như sau:

```bash
docker run -d \
  --name app-container \
  --network app-net \
  -p 3000:3000 \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=appdb \
  -e DB_USER=appuser \
  -e DB_PASSWORD=app123 \
  hw-backend:v1
```

Kiểm tra trạng thái:

```bash
docker ps
```

Kiểm tra các container trong Network:

```bash
docker network inspect app-net
```

**Giải thích:**

- `app-container` và `db-server` cùng tham gia Network `app-net`.
- Backend sử dụng hostname `db-server` để tìm Database Container thông qua Docker DNS.
- Cổng `5432` là cổng PostgreSQL bên trong Network.
- Cổng `3000` được ánh xạ để truy cập Backend từ máy host.

## 8. Kiểm tra khả năng kết nối Database

Thực hiện lệnh sau để mở PostgreSQL client bên trong Database Container:

```bash
docker exec -it db-server psql -U appuser -d appdb
```

Trong PostgreSQL, kiểm tra cơ sở dữ liệu:

```sql
SELECT current_database();
```

Liệt kê các bảng:

```sql
\dt
```

Thoát PostgreSQL client:

```sql
\q
```

Nếu Backend có endpoint kiểm tra API, hãy truy cập endpoint tương ứng để xác nhận ứng dụng hoạt động.

## 9. Kiểm tra tính bền vững của dữ liệu

### 9.1. Tạo bảng và dữ liệu thử nghiệm

Mở PostgreSQL client:

```bash
docker exec -it db-server psql -U appuser -d appdb
```

Tạo bảng và thêm dữ liệu:

```sql
CREATE TABLE volume_test (
    id SERIAL PRIMARY KEY,
    message VARCHAR(100)
);

INSERT INTO volume_test (message)
VALUES ('Docker Named Volume works!');
```

Kiểm tra dữ liệu:

```sql
SELECT * FROM volume_test;
```

Thoát PostgreSQL client:

```sql
\q
```

### 9.2. Xóa Database Container

```bash
docker rm -f db-server
```

Lệnh này xóa container `db-server` nhưng không xóa Named Volume `db-data`.

### 9.3. Tạo lại Database Container

Khởi chạy lại PostgreSQL với cùng Network, thông tin đăng nhập và Named Volume:

```bash
docker run -d \
  --name db-server \
  --network app-net \
  -e POSTGRES_DB=appdb \
  -e POSTGRES_USER=appuser \
  -e POSTGRES_PASSWORD=app123 \
  -v db-data:/var/lib/postgresql/data \
  postgres:15-alpine
```

Đợi PostgreSQL sẵn sàng:

```bash
docker exec db-server pg_isready -U appuser -d appdb
```

Kiểm tra dữ liệu sau khi tạo lại container:

```bash
docker exec -it db-server psql -U appuser -d appdb -c "SELECT * FROM volume_test;"
```

**Kết quả mong đợi:** Bản ghi `Docker Named Volume works!` vẫn tồn tại sau khi Database Container được xóa và tạo lại.