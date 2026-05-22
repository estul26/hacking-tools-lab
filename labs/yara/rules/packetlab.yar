rule PacketLab_Text_Indicator : local_training text
{
    meta:
        author = "PacketLab"
        description = "Matches the generated PacketLab text fixture"
        severity = "training"
    strings:
        $marker = "PacketLab YARA local fixture"
        $url = "http://127.0.0.1:8080/yara"
        $token = "API_TOKEN=LOCAL-TRAINING-ONLY"
    condition:
        all of them
}

rule PacketLab_Binary_Indicator : local_training binary
{
    meta:
        author = "PacketLab"
        description = "Matches the generated binary fixture"
        severity = "training"
    strings:
        $elf = { 7F 45 4C 46 }
        $marker = "PACKETLAB_BINARY_MARKER"
    condition:
        $elf at 0 and $marker
}

rule PacketLab_Nested_Config : local_training config
{
    meta:
        author = "PacketLab"
        description = "Matches the generated nested config fixture"
        severity = "training"
    strings:
        $section = "[packetlab]"
        $marker = "PACKETLAB_NESTED_MARKER"
    condition:
        all of them
}

rule PacketLab_Regex_Url : local_training regex
{
    meta:
        author = "PacketLab"
        description = "Matches local-only PacketLab URLs"
        severity = "training"
    strings:
        $local_url = /http:\/\/127\.0\.0\.1:[0-9]+\/[a-z]+/
    condition:
        $local_url
}

rule PacketLab_Size_Gate : local_training sizecheck
{
    meta:
        author = "PacketLab"
        description = "Matches small generated files containing PacketLab text"
        severity = "training"
    strings:
        $packetlab = "PacketLab"
    condition:
        filesize < 1KB and $packetlab
}
