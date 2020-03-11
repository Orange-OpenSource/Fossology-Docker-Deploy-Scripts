In this folder, add your own license definitions, in CSV format

To create CSV license file:
1. add it via the web interface,
1. and then export it to CSV from psql.

Command example to extract a given licence: 

```
\copy (select * from license_ref where rf_shortname = 'Orange-Proprietary') to /tmp/out.csv with csv`
```

