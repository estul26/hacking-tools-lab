FROM python:3.13-slim

COPY winrm_mock.py /usr/local/bin/winrm_mock.py
COPY start-target.sh /usr/local/bin/start-target.sh

RUN chmod +x /usr/local/bin/start-target.sh

EXPOSE 5985

CMD ["/usr/local/bin/start-target.sh"]
