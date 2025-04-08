import os
import subprocess
import gzip
import boto3
from datetime import datetime

# --------- CONFIGURATION ---------
DB_NAME = "your_database_name"
DB_USER = "your_db_user"
DB_HOST = "your_db_host"
S3_BUCKET_NAME = "your-s3-backup-bucket"
BACKUP_DIR = "/tmp/db_backups"
DELETE_LOCAL_AFTER_UPLOAD = True
# ---------------------------------

# Generate timestamped filename
timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
filename = f"{DB_NAME}_backup_{timestamp}.sql.gz"
local_path = os.path.join(BACKUP_DIR, filename)

def create_backup():
    os.makedirs(BACKUP_DIR, exist_ok=True)
    dump_cmd = ["pg_dump", "-U", DB_USER, "-h", DB_HOST, DB_NAME]
    print(f"🔄 Creating backup for database '{DB_NAME}'...")

    try:
        with open(local_path, "wb") as f_out:
            with gzip.GzipFile(fileobj=f_out, mode='wb') as gz_out:
                process = subprocess.Popen(dump_cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=False)
                for chunk in iter(lambda: process.stdout.read(1024), b''):
                    gz_out.write(chunk)
                _, err = process.communicate()
                if process.returncode != 0:
                    raise Exception(f"pg_dump failed: {err.decode()}")
        print(f"✅ Backup file created: {local_path}")
    except Exception as e:
        print(f"❌ Backup failed: {e}")
        exit(1)

def upload_to_s3():
    print(f"⬆️  Uploading backup to S3 bucket: {S3_BUCKET_NAME}...")
    s3 = boto3.client("s3")
    try:
        s3.upload_file(local_path, S3_BUCKET_NAME, filename, ExtraArgs={"StorageClass": "STANDARD_IA"})
        print(f"✅ Backup uploaded to S3 as '{filename}'")
    except Exception as e:
        print(f"❌ Upload to S3 failed: {e}")
        exit(2)

def clean_up():
    if DELETE_LOCAL_AFTER_UPLOAD:
        os.remove(local_path)
        print("🧹 Local backup file removed.")

if __name__ == "__main__":
    create_backup()
    upload_to_s3()
    clean_up()
