FROM python:3.8-slim-buster

WORKDIR src

COPY requirements.txt requirements.txt
ENV CRYPTOGRAPHY_DONT_BUILD_RUST=1

# https://github.com/docker-library/python/issues/60
# and https://stackoverflow.com/questions/58393840/fatal-error-ffi-h-no-such-file-or-directory-on-pip2-install-pyopenssl
# and https://stackoverflow.com/questions/54361961/i-am-getting-error-the-make-utility-is-missing-from-path-when-i-am-building-do
# and https://stackoverflow.com/a/66118921/1040915
RUN apt-get update \
    && apt-get install -y --no-install-recommends python-dev libffi-dev openssl libssl-dev gcc make \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install -r requirements.txt \
    && apt-get purge -y --auto-remove python-dev libffi-dev openssl libssl-dev gcc make

COPY . .

CMD ["python3", "run.py"]

