#!/usr/bin/env python3
import argparse
import csv
import shutil
import subprocess
import sys
from pathlib import Path


PACKET_FIELDS = [
    ("frame.number", "No."),
    ("frame.time_relative", "Time"),
    ("_ws.col.Source", "Source"),
    ("_ws.col.Destination", "Destination"),
    ("_ws.col.Protocol", "Protocol"),
    ("frame.len", "Len"),
    ("_ws.col.Info", "Info"),
]

DECODE_AS = [
    "-d",
    "tcp.port==8080,http",
    "-d",
    "tcp.port==2525,smtp",
    "-d",
    "udp.port==5300,dns",
]


def require_tshark():
    if not shutil.which("tshark"):
        raise SystemExit("tshark was not found. Run this inside the analyzer container.")


def run_tshark(args):
    require_tshark()
    result = subprocess.run(
        ["tshark", *args],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr.strip(), file=sys.stderr)
        raise SystemExit(result.returncode)
    return result.stdout


def read_field_rows(pcap, display_filter, fields):
    args = [
        "-r",
        str(pcap),
        *DECODE_AS,
        "-T",
        "fields",
        "-E",
        "header=y",
        "-E",
        "separator=\t",
        "-E",
        "quote=n",
        "-E",
        "occurrence=f",
    ]
    if display_filter:
        args.extend(["-Y", display_filter])
    for field, _ in fields:
        args.extend(["-e", field])

    output = run_tshark(args)
    return list(csv.reader(output.splitlines(), delimiter="\t"))


def truncate(value, width):
    if len(value) <= width:
        return value
    if width <= 3:
        return value[:width]
    return value[: width - 3] + "..."


def print_table(headers, rows, limit):
    rows = rows[:limit]
    if not rows:
        print("No packets matched.")
        return

    widths = [len(header) for header in headers]
    for row in rows:
        for index, value in enumerate(row):
            widths[index] = max(widths[index], min(len(value), 72))

    template = "  ".join(f"{{:<{width}}}" for width in widths)
    print(template.format(*headers))
    print(template.format(*["-" * width for width in widths]))
    for row in rows:
        padded = row + [""] * (len(headers) - len(row))
        print(template.format(*[truncate(value, widths[index]) for index, value in enumerate(padded)]))


def show_packets(args):
    rows = read_field_rows(args.pcap, args.display_filter, PACKET_FIELDS)
    if not rows:
        print("No packets found.")
        return
    headers = [label for _, label in PACKET_FIELDS]
    print_table(headers, rows[1:], args.limit)


def show_http(args):
    fields = [
        ("frame.number", "No."),
        ("ip.src", "Source"),
        ("ip.dst", "Destination"),
        ("http.request.method", "Method"),
        ("http.host", "Host"),
        ("http.request.uri", "URI"),
        ("http.response.code", "Status"),
    ]
    rows = read_field_rows(args.pcap, "http", fields)
    headers = [label for _, label in fields]
    print_table(headers, rows[1:] if rows else [], args.limit)


def show_dns(args):
    fields = [
        ("frame.number", "No."),
        ("ip.src", "Source"),
        ("ip.dst", "Destination"),
        ("dns.qry.name", "Query"),
        ("dns.a", "Answer"),
        ("_ws.col.Info", "Info"),
    ]
    rows = read_field_rows(args.pcap, "dns", fields)
    headers = [label for _, label in fields]
    print_table(headers, rows[1:] if rows else [], args.limit)


def show_statistics(args):
    stats = {
        "protocols": ["-q", "-z", "io,phs"],
        "conversations": ["-q", "-z", "conv,tcp", "-z", "conv,udp"],
    }
    print(run_tshark(["-r", str(args.pcap), *DECODE_AS, *stats[args.command]]).strip())


def existing_pcap(value):
    path = Path(value)
    if not path.exists():
        raise argparse.ArgumentTypeError(f"{value} does not exist")
    return path


def build_parser():
    parser = argparse.ArgumentParser(
        description="Small Wireshark-style terminal viewer backed by tshark.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    packets = subparsers.add_parser("packets", help="show a packet list")
    packets.add_argument("pcap", type=existing_pcap)
    packets.add_argument("-Y", "--display-filter", default="", help="Wireshark display filter")
    packets.add_argument("--limit", type=int, default=40)
    packets.set_defaults(func=show_packets)

    http = subparsers.add_parser("http", help="show HTTP request and response fields")
    http.add_argument("pcap", type=existing_pcap)
    http.add_argument("--limit", type=int, default=40)
    http.set_defaults(func=show_http)

    dns = subparsers.add_parser("dns", help="show DNS query and answer fields")
    dns.add_argument("pcap", type=existing_pcap)
    dns.add_argument("--limit", type=int, default=40)
    dns.set_defaults(func=show_dns)

    protocols = subparsers.add_parser("protocols", help="show protocol hierarchy statistics")
    protocols.add_argument("pcap", type=existing_pcap)
    protocols.set_defaults(func=show_statistics)

    conversations = subparsers.add_parser("conversations", help="show TCP and UDP conversations")
    conversations.add_argument("pcap", type=existing_pcap)
    conversations.set_defaults(func=show_statistics)

    return parser


def main():
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
