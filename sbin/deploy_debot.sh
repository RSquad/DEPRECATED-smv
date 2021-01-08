#!/bin/bash
set -e
tonoscli=../bin/tonos-cli
debot=DemiurgeDebot
debot_abi=../src/$debot.abi.json
debot_tvc=../src/$debot.tvc
debot_keys=../src/$debot.keys.json
giver=0:841288ed3b55d9cdafa806807f02a0ae0c169aa5edfe88a789a6482429756a94
target_address=0:0000000000000000000000000000000000000000000000000000000000000000
price_provider=0:0000000000000000000000000000000000000000000000000000000000000000
function giver {
    $tonoscli call --abi ../data/nse-giver.abi.json $giver sendGrams "{\"dest\":\"$1\",\"amount\":10000000000}"
}
function get_address {
echo $(cat log.log | grep "Raw address:" | cut -d ' ' -f 3)    
}

$tonoscli config --url http://0.0.0.0

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
si=$(cat ../src/VotingDebot.tvc | base64 )
$tonoscli call $debot_address setVotingDebotSI "{\"state\":\"$si\"}" --sign $debot_keys --abi $debot_abi
si=$(cat ../data/Proposal.tvc | base64 )
$tonoscli call $debot_address setProposalImage "{\"image\":\"$si\"}" --sign $debot_keys --abi $debot_abi
si=$(cat ../data/Padavan.tvc | base64 )
$tonoscli call $debot_address setPadavanImage "{\"image\":\"$si\"}" --sign $debot_keys --abi $debot_abi
si=$(cat ../data/Demiurge.tvc | base64 )
$tonoscli call $debot_address setDemiurgeImage "{\"image\":\"$si\"}" --sign $debot_keys --abi $debot_abi

echo DONE
echo $debot_address > address.log

#Test seed phrase
#fiber immense funny indoor improve federal jealous weird office south net eager
#pubkey
#0xd16572a3d454113535a5f29ef8b70539fcee26b3b157ee3321efcaff4cfa7728

#pluck attitude fashion earn fashion shoulder solid basic rebel jewel tenant spirit
#0x801fe857364d946a0b6b7a88510aa49feb5341e1080c10986367876475b1bf10

#voting debot
#0:298efb518e60519c28e38446066e6e363601e7c2021ce6b595d8673fce6c95f8

$tonoscli debot fetch $debot_address