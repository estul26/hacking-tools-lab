rule PacketLab_External_Mode : local_training external
{
    meta:
        author = "PacketLab"
        description = "Requires external variable lab_mode to equal local"
        severity = "training"
    strings:
        $marker = "PacketLab YARA local fixture"
    condition:
        lab_mode == "local" and $marker
}
