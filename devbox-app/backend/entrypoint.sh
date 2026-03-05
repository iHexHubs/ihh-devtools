#!/usr/bin/env bash
set -euo pipefail

python manage.py migrate --noinput
python manage.py collectstatic --noinput || true

exec gunicorn backend_project.wsgi:application --bind 0.0.0.0:8000 --workers 2 --timeout 60
