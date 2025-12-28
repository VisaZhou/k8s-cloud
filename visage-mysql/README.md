## 前置操作
执行以下sql，修改root用户的认证方式，避免 nacos 启动初始化连接失败问题：
```sql
ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'zxj201328';
```