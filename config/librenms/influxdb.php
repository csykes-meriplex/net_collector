<?php
// LibreNMS InfluxDB v2 output — metrics pushed here, visualized in Grafana.
// Token and org are read from container environment (set in .env).
$config['influxdb']['transport'] = 'http';
$config['influxdb']['host']      = 'influxdb';
$config['influxdb']['port']      = 8086;
$config['influxdb']['v2']        = true;
$config['influxdb']['orgId']     = getenv('INFLUXDB_ORG') ?: 'netcollector';
$config['influxdb']['token']     = getenv('INFLUXDB_ADMIN_TOKEN');
$config['influxdb']['bucket']    = 'librenms';
