# README

* For local SQLite replication, make sure you have a `.env.development` file in your application root directory that contains the following:

MISSION_CONTROL_USERNAME=your_mission_control_username
MISSION_CONTROL_PASSWORD=your_mission_control_password

start minio with:

```
bin/rails minio:server -- --console-address=:9001
```
