cd /mnt/BERTHA/ha_backups
rm *.tar
scp -r -o StrictHostKeyChecking=no hass:/backup/*.tar .

# I wish there was a good scp module for Python but paramiko succccksssss
python3 -c "import os, tarfile json, datetime; transformed = [json.load(tarfile.open(name).extractfile('./snapshot.json')) for name in os.listdir('.') if name.endswith('.tar')]; latest = sorted(transformed, key=lambda snap: datetime.datetime.strptime(snap['date'], '%Y-%m-%dT%H:%M:%S.%f%z'))[-1]; metadata_file = open('metadata', 'w'); metadata_file.write('latest_file:' + latest['slug'] + '.tar\ntimestamp:' + latest['date'] + '\n'); metadata_file.close()"
