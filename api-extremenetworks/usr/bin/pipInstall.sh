#!/bin/bash

set -e

python -m venv /var/lib/python-venv
source /var/lib/python-venv/bin/activate
python -m pip install -r /var/www/api/api/pip.requirements
deactivate

exit 0
