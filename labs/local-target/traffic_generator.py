import http.client
import os
import random
import socket
import struct
import time


TARGET_HOST = os.getenv("TARGET_HOST", "local-target")
INTERVAL_SECONDS = float(os.getenv("TRAFFIC_INTERVAL_SECONDS", "5"))
ONCE = os.getenv("ONCE", "").lower() in {"1", "true", "yes"}


def log(message):
    print(message, flush=True)


def wait_for_target():
    for _ in range(30):
        try:
            with socket.create_connection((TARGET_HOST, 8080), timeout=1):
                log("target: ready")
                return
        except OSError:
            time.sleep(1)
    log("target: continuing without readiness confirmation")


def http_get(path):
    connection = http.client.HTTPConnection(TARGET_HOST, 8080, timeout=3)
    connection.request("GET", path, headers={"User-Agent": "local-target-traffic/1.0"})
    response = connection.getresponse()
    response.read()
    log(f"http: GET {path} -> {response.status}")
    connection.close()


def http_login():
    body = "username=analyst&password=packetlab"
    connection = http.client.HTTPConnection(TARGET_HOST, 8080, timeout=3)
    connection.request(
        "POST",
        "/login",
        body=body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Content-Length": str(len(body)),
            "User-Agent": "local-target-traffic/1.0",
        },
    )
    response = connection.getresponse()
    response.read()
    log(f"http: POST /login -> {response.status}")
    connection.close()


def talk_smtp():
    with socket.create_connection((TARGET_HOST, 2525), timeout=3) as sock:
        sock.recv(512)
        sock.sendall(b"EHLO generator.local-target.lab\r\n")
        sock.recv(1024)
        sock.sendall(b"QUIT\r\n")
        sock.recv(512)
    log("smtp: completed EHLO/QUIT")


def talk_redis():
    with socket.create_connection((TARGET_HOST, 6379), timeout=3) as sock:
        sock.sendall(b"*1\r\n$4\r\nPING\r\n")
        response = sock.recv(512)
    log(f"redis: {response.decode('ascii', errors='replace').strip()}")


def encode_dns_name(name):
    encoded = bytearray()
    for label in name.rstrip(".").split("."):
        label_bytes = label.encode("ascii")
        encoded.append(len(label_bytes))
        encoded.extend(label_bytes)
    encoded.append(0)
    return bytes(encoded)


def query_dns():
    transaction_id = random.randint(0, 65535)
    header = struct.pack("!HHHHHH", transaction_id, 0x0100, 1, 0, 0, 0)
    question = encode_dns_name("target.local-target.lab") + struct.pack("!HH", 1, 1)
    packet = header + question

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(3)
        sock.sendto(packet, (TARGET_HOST, 5300))
        response, _ = sock.recvfrom(512)

    response_id = struct.unpack("!H", response[:2])[0]
    log(f"dns: response id {response_id}")


def run_iteration(iteration):
    paths = [
        "/",
        "/api/status",
        "/api/users",
        "/api/orders?owner=analyst",
        f"/search?q=iteration-{iteration}",
        "/redirect",
    ]
    for path in paths:
        http_get(path)
    http_login()
    talk_smtp()
    talk_redis()
    query_dns()


def main():
    wait_for_target()
    iteration = 1
    while True:
        run_iteration(iteration)
        if ONCE:
            break
        iteration += 1
        time.sleep(INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
