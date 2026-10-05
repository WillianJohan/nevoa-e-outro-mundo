-- Sirene do evento de névoa (sprint 0009, ADR-009), no jogo de quem ouve: solo
-- (o server/NOM_FogEvent.lua chama direto) e cliente de MP (comando "siren", em
-- client/NOM_FogClient.lua). Toca no emitter do jogador local, sem pacote:
-- player:playSoundLocal = getEmitter():playSoundImpl(nome, nil) (bytecode
-- IsoGameCharacter.playSoundLocal; uso vanilla client/ISUI/Maps/ISMap.lua:210).
-- Sai da posição do próprio jogador, então se ouve em qualquer lugar do mapa.
-- media/scripts/NOM_sounds.txt; RED = sirene da névoa vermelha (sprint 0010)
NOM_Siren = { SOUND = "NOM_Siren", RED = "NOM_SirenRed" }

-- Devolve o id do som, ou nil sem jogador local.
function NOM_Siren.play(red)
    local p = getSpecificPlayer(0) -- getPlayer() é o jogador em foco na tela dividida
    if not p then return nil end
    local id = p:playSoundLocal(red and NOM_Siren.RED or NOM_Siren.SOUND)
    p:getEmitter():setVolume(id, 1) -- CharacterSoundEmitter.setVolume(JF) (pz-api-notes §4.3)
    return id
end

return NOM_Siren
