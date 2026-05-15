import subprocess
import os
from flask import Flask, request, jsonify


app = Flask(__name__)

PROJECT_DIR = "/app/earnings_call_transforms"
PROFILES_DIR = "/root/.dbt"

@app.route("/", methods=["POST"])
def run_dbt():
    payload = request.get_json(silent=True) or {}

    command = payload.get("dbt_command", "run")
    select = payload.get("select")

    cmd = ["dbt", command,
           "--project-dir", PROJECT_DIR,
           "--profiles-dir", PROFILES_DIR]

    if select:
        cmd += ["--select", select]

    result = subprocess.run(cmd, capture_output=True, text=True)

    return jsonify({
        "stdout": result.stdout,
        "stderr": result.stderr,
        "returncode": result.returncode
    }), 200 if result.returncode == 0 else 500

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)