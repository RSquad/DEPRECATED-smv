#!/bin/bash
set -e
tonoscli=../bin/tonos-cli
debot=DemiurgeDebot
debot_abi=../src/$debot.abi.json
debot_tvc=../src/$debot.tvc
debot_keys=../src/$debot.keys.json
giver=0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94
#demiurge
target_address=0:3bca99c754030c7ecbedc5ef1eb9b6c634d05b4a3de5abe30ac1d9d3908242f3
price_provider=0:d235a844700b0875efc00c29985dbd1929c6ac3a4e421e4f02b58d3652936d84
function giver {
    $tonoscli call --abi ../data/nse-giver.abi.json $giver sendGrams "{\"dest\":\"$1\",\"amount\":10000000000}"
}
function get_address {
echo $(cat log.log | grep "Raw address:" | cut -d ' ' -f 3)
}

$tonoscli config --url http://127.0.0.1

echo GENADDR DEBOT
$tonoscli genaddr $debot_tvc $debot_abi --genkey $debot_keys > log.log
debot_address=$(get_address)
echo debot address = $debot_address
echo GIVER
giver $debot_address

echo DEPLOY DEBOT
dabi=$(cat $debot_abi | xxd -ps -c 20000)
$tonoscli deploy $debot_tvc "{\"demi\":\"$target_address\",\"priceProv\":\"$price_provider\",\"debotAbi\":\"$dabi\"}" --sign $debot_keys --abi $debot_abi
echo SETTERS DEBOT
sabi=$(cat ../data/Demiurge.abi.json | xxd -ps -c 20000)
$tonoscli call $debot_address setDemiurgeABI "{\"sabi\":\"$sabi\"}" --sign $debot_keys --abi $debot_abi
sabi=$(cat ../src/VotingDebot.abi.json | xxd -ps -c 20000)
$tonoscli call $debot_address setVotingDebotABI "{\"sabi\":\"$sabi\"}" --sign $debot_keys --abi $debot_abi
sabi=$(cat ../data/Padavan.abi.json | xxd -ps -c 20000)
$tonoscli call $debot_address setPadavanABI "{\"sabi\":\"$sabi\"}" --sign $debot_keys --abi $debot_abi
sabi=$(cat ../data/Proposal.abi.json | xxd -ps -c 20000)
$tonoscli call $debot_address setProposalABI "{\"sabi\":\"$sabi\"}" --sign $debot_keys --abi $debot_abi
si=$(cat ../src/VotingDebot.tvc | base64 --wrap=0 )
$tonoscli call $debot_address setVotingDebotSI "{\"state\":\"$si\"}" --sign $debot_keys --abi $debot_abi
si=$(cat ../data/Proposal.tvc | base64 --wrap=0 )
$tonoscli call $debot_address setProposalImage "{\"image\":\"$si\"}" --sign $debot_keys --abi $debot_abi
si=$(cat ../data/Padavan.tvc | base64 --wrap=0 )
$tonoscli call $debot_address setPadavanImage "{\"image\":\"$si\"}" --sign $debot_keys --abi $debot_abi
si=$(cat ../data/Demiurge.tvc | base64 --wrap=0 )
$tonoscli call $debot_address setDemiurgeImage "{\"image\":\"$si\"}" --sign $debot_keys --abi $debot_abi

echo DONE
echo $debot_address > address.log

#Test seed phrase
#fiber immense funny indoor improve federal jealous weird office south net eager
#pubkey
#0xd16572a3d454113535a5f29ef8b70539fcee26b3b157ee3321efcaff4cfa7728

#pluck attitude fashion earn fashion shoulder solid basic rebel jewel tenant spirit
#0x801fe857364d946a0b6b7a88510aa49feb5341e1080c10986367876475b1bf10

#moon robust siren diamond reform horse glue web olympic lady two amateur
#ee539861fbd6a7c9f55e96df0d76968f60332ed1ccfb7866c5a82717ee360d66

#taste anxiety aim pilot two indicate quiz fix enjoy ring deputy minute
#0xa94d2b6271bf9b69a2b73166d21b221c332e2c0ac216bd0aca3606a7eb2c2454

#baby sign evil orphan cup kite kick rude village army ten night
#0x1d200a3196ff79e3c6ec53d3dcfe85e929215d4a2b2239dd6bff5c4ece3e4ef6

#voting debot
#0:298efb518e60519c28e38446066e6e363601e7c2021ce6b595d8673fce6c95f8
#0:e9748538d1cfa5556e9c8e3097f6d2be301d20f4b9d7eeb4b89356c1768543bd devnet
#0:af7cda0a7bdc5f083ff8e801de3c4701279d2ba636122f20ae5b6d20c34fde27

#price provider
#Seed phrase: "baby sign evil orphan cup kite kick rude village army ten night"
#Raw address: 0:ec3f1ac79bcc9cf7c74783424f0590379ce7b3f8542e031db09b75f5e44d0076

#demi debot
#Seed phrase: "inside total grocery route gloom drop bag candy bulk cigar bachelor jelly"
#Raw address: 0:1effe680f2faddb8eb77ddc6c08551a1e91fb57ca9bd0c03f82c91becf99b1e8

#demiurge
#0:52697FC1FA3EC7FD0F3727E3EBD515DB3FB0491827124EB3A12847D935882030


$tonoscli debot fetch $debot_address