"""Generate sandbox declarations and translation assets from the Lua settings."""
import json
from pathlib import Path

from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / 'Contents/mods/SurvivorPDAOrchestrator'
MEDIA = MOD / '42/media'
LUA = MEDIA / 'lua'
runtime = LuaRuntime(unpack_returned_tuples=True)
runtime.execute("package.preload.PRPGE_Settings = function() return {DEFS={}, BY_KEY={}} end")
runtime.execute("package.path = ... .. '/shared/?.lua;' .. package.path", LUA.as_posix())
config = runtime.eval("require('SPDO/Config')")

labels = {
    'Enabled': ('Enable Orchestrator', 'Ativar Orquestrador'),
    'Preset': ('Event frequency preset', 'Preset de frequência dos eventos'),
    'IntervalMin': ('Custom: minimum interval (played minutes)', 'Personalizado: intervalo mínimo (minutos jogados)'),
    'IntervalMax': ('Custom: maximum interval (played minutes)', 'Personalizado: intervalo máximo (minutos jogados)'),
    'RetryMinutes': ('Blocked decision: retry after (played minutes)', 'Decisão bloqueada: tentar após (minutos jogados)'),
    'HealthMin': ('Horde target: minimum health (%)', 'Alvo de horda: saúde mínima (%)'),
    'EnduranceMin': ('Horde target: minimum endurance (%)', 'Alvo de horda: resistência mínima (%)'),
    'FatigueMax': ('Horde target: maximum fatigue (%)', 'Alvo de horda: fadiga máxima (%)'),
    'BlockBleeding': ('Protect bleeding survivors', 'Proteger sobreviventes sangrando'),
    'DamageGrace': ('Protection after damage (played minutes)', 'Proteção após dano (minutos jogados)'),
    'JoinGrace': ('Protection after joining or spawning (played minutes)', 'Proteção após entrar ou nascer (minutos jogados)'),
    'BlockSleeping': ('Protect sleeping survivors', 'Proteger sobreviventes dormindo'),
    'BlockVehicles': ('Protect survivors in vehicles', 'Proteger sobreviventes em veículos'),
    'NeighborRadius': ('Protect vulnerable neighbors within (tiles)', 'Proteger vizinhos vulneráveis a até (tiles)'),
    'RecoveryMinutes': ('Rest after death or horde (played minutes)', 'Descanso após morte ou horda (minutos jogados)'),
    'KillThreshold': ('Intense combat: kills in five played minutes (0 = off)', 'Combate intenso: abates em cinco minutos jogados (0 = desligado)'),
    'ExtractionProtection': ('Protect Extraction Mode hideouts and transitions', 'Proteger esconderijos e transições do Extraction Mode'),
    'HordeEnabled': ('Allow director hordes alongside native hordes', 'Permitir hordas do diretor junto às hordas nativas'),
    'NightThreatMultiplier': ('Night threat chance multiplier (20:00–06:00)', 'Multiplicador da chance de ameaça noturna (20h–6h)'),
    'NightEventsEnabled': ('Enable Night Events', 'Ativar eventos noturnos'),
    'NightEventsChance': ('Night Event chance per night (%)', 'Chance de Night Event por noite (%)'),
}
for level in range(1, 5):
    labels[f'NightLevel{level}Weight'] = (f'Level {level} chance weight (%)', f'Peso da chance do nível {level} (%)')
    labels[f'NightLevel{level}LootBonus'] = (f'Level {level} loot chance bonus (%)', f'Bônus de chance de loot do nível {level} (%)')
    labels[f'NightLevel{level}SprinterPercentage'] = (f'Level {level} sprinter chance (%)', f'Chance de sprinter do nível {level} (%)')
strings = {
    'Title': ('ORCHESTRATOR', 'ORQUESTRADOR'), 'Rare': ('Rare (60–120 min)', 'Raro (60–120 min)'),
    'Moderate': ('Moderate (30–60 min)', 'Moderado (30–60 min)'),
    'Frequent': ('Frequent (15–30 min)', 'Frequente (15–30 min)'), 'Custom': ('Custom', 'Personalizado'),
    'Diagnostics': ('Diagnostics', 'Diagnóstico'), 'General': ('General', 'Geral'), 'Protection': ('Protection', 'Proteção'),
    'Events': ('Events', 'Eventos'), 'State': ('Director state', 'Estado do diretor'),
    'NightEvents': ('Night Events', 'Eventos noturnos'),
    'NightEventStarted': ('NIGHT EVENT!', 'EVENTO NOTURNO!'),
    'NightEventDescription': ('Container loot +%s; sprinters %s until dawn.', 'Loot em containers +%s; sprinters %s até amanhecer.'),
    'NightEventTag': ('NIGHT LUCK', 'SORTE NOTURNA'),
    'StartNightEvent': ('Start Night Event', 'Iniciar evento noturno'),
    'EndNightEvent': ('End Night Event', 'Encerrar evento noturno'),
    'NightEventStatus': ('Night Event status', 'Estado do evento noturno'),
    'NightStatusActive': ('Active — Level %s', 'Ativo — Nível %s'),
    'NightStatusDisabled': ('Disabled in settings', 'Desativado nas configurações'),
    'NightStatusDay': ('Waiting for nightfall', 'Aguardando anoitecer'),
    'NightStatusInactive': ('Inactive tonight', 'Inativo nesta noite'),
    'StartNightEventTip': ('Starts the Night Event now. Night Events must be enabled and it must be nighttime.', 'Inicia o evento noturno agora. Os eventos noturnos precisam estar ativados e deve ser noite.'),
    'EndNightEventTip': ('Ends the current Night Event for everyone.', 'Encerra o evento noturno atual para todos.'),
    'NightStarted': ('Night Event started.', 'Evento noturno iniciado.'),
    'NightEnded': ('Night Event ended.', 'Evento noturno encerrado.'),
    'NightDisabled': ('Enable Night Events in settings first.', 'Ative os eventos noturnos nas configurações primeiro.'),
    'NightNotNight': ('A Night Event can only start at night.', 'Um evento noturno só pode começar durante a noite.'),
    'NightAlreadyActive': ('A Night Event is already active.', 'Já existe um evento noturno ativo.'),
    'NightNotActive': ('There is no active Night Event to end.', 'Não há evento noturno ativo para encerrar.'),
    'NightUnavailable': ('Night Event state is unavailable.', 'O estado do evento noturno está indisponível.'),
    'NightAlert1': ('A small stroke of luck. Something fast is hunting nearby.', 'Uma pequena dose de sorte. Algo rápido está caçando por perto.'),
    'NightAlert2': ('Fortune smiles, but the dead are moving faster. Stay sharp.', 'A fortuna sorri, mas os mortos estão mais rápidos. Fique atento.'),
    'NightAlert3': ('The night offers riches. The dead are running in numbers. Keep moving.', 'A noite oferece riquezas. Os mortos correm em bandos. Não pare.'),
    'NightAlert4': ('Fortune is at its peak. Sprinters are everywhere. Run.', 'A sorte está no auge. Há sprinters por toda parte. Corra.'),
    'DawnAlert': ('Dawn breaks. The dead have slowed, but the night’s warning still stands: stay alert.', 'O dia amanhece. Os mortos desaceleraram, mas o aviso da noite permanece: fique alerta.'),
    'DecideNow': ('Make a decision now', 'Tomar uma decisão agora'),
    'DecisionRequested': ('Decision request sent to the server.', 'Pedido de decisão enviado ao servidor.'),
    'ForceDecisionTip': ('Evaluate the current world now. Existing events and survivor protections still apply.', 'Avalia o mundo agora. Eventos em andamento e proteções dos sobreviventes continuam valendo.'),
    'LastForcedDecision': ('Last requested decision', 'Última decisão solicitada'),
    'ForceRequest': ('Manual decision request', 'Pedido de decisão manual'),
    'ForceCooldown': ('Please wait before requesting another decision.', 'Aguarde antes de solicitar outra decisão.'),
    'NextDecision': ('Next decision in', 'Próxima decisão em'), 'RecoveryTime': ('Rest remaining', 'Descanso restante'),
    'Players': ('Living players', 'Jogadores vivos'), 'WorldDanger': ('World Danger', 'Perigo mundial'),
    'WorldTime': ('World time (hours)', 'Horário do mundo (horas)'),
    'History': ('LAST 20 DECISIONS (played time)', 'ÚLTIMAS 20 DECISÕES (tempo jogado)'),
    'Running': ('Running event', 'Evento em andamento'), 'Stale': ('Waiting for a fresh server response…', 'Aguardando nova resposta do servidor…'),
    'NativeClock': ('Started event durations follow ProjectRPG real time, including offline time.', 'A duração dos eventos iniciados segue o tempo real do ProjectRPG, incluindo períodos offline.'),
    'NativeHordes': ('Native kill-triggered hordes remain enabled and can fire independently.', 'Hordas nativas por abates continuam ativas e podem começar de forma independente.'),
    'Initializing': ('Waiting for the authority…', 'Aguardando a autoridade…'), 'Disabled': ('Disabled', 'Desativado'),
    'Waiting': ('Waiting for the next decision', 'Aguardando a próxima decisão'),
    'UnknownPlayerState': ('Required survivor data unavailable', 'Dados necessários do sobrevivente indisponíveis'),
    'LowHealth': ('Low health', 'Saúde baixa'), 'LowEndurance': ('Low endurance', 'Resistência baixa'),
    'HighFatigue': ('High fatigue', 'Fadiga alta'), 'Bleeding': ('Bleeding', 'Sangramento'),
    'Sleeping': ('Sleeping', 'Dormindo'), 'Vehicle': ('Inside a vehicle', 'Dentro de um veículo'),
    'JoinGrace': ('Protected after joining or spawning', 'Protegido após entrar ou nascer'),
    'RecentDamage': ('Recently hurt', 'Sofreu dano recentemente'), 'IntenseCombat': ('Recent intense combat', 'Combate intenso recente'),
    'ExtractionUnknown': ('Extraction Mode state unavailable', 'Estado do Extraction Mode indisponível'),
    'ExtractionProtected': ('Protected Extraction Mode location or transition', 'Local ou transição protegida do Extraction Mode'),
    'VulnerableNeighbor': ('Vulnerable survivor nearby', 'Sobrevivente vulnerável por perto'),
    'DeathRecovery': ('Rest started after a death', 'Descanso iniciado após uma morte'),
    'HordeRecovery': ('Rest started after a horde', 'Descanso iniciado após uma horda'),
    'EventFinished': ('Director event finished', 'Evento do diretor encerrado'),
    'DirectorEvent': ('Director event running', 'Evento do diretor em andamento'),
    'NoPlayers': ('No living players', 'Nenhum jogador vivo'), 'ActiveEvent': ('Waiting for existing events to end', 'Aguardando os eventos existentes terminarem'),
    'Recovery': ('Rest period', 'Período de descanso'), 'NoEligibleEvent': ('No eligible event', 'Nenhum evento elegível'),
    'NoSafeTarget': ('No safe horde target', 'Nenhum alvo seguro para horda'), 'TargetChanged': ('Target changed; attack cancelled', 'Alvo mudou; ataque cancelado'),
    'StartFailed': ('Native event could not start', 'Não foi possível iniciar o evento nativo'),
    'ThreatStarted': ('Threat selected', 'Ameaça selecionada'), 'OpportunityStarted': ('Opportunity selected', 'Oportunidade selecionada'),
    'HordesDisabled': ('Hordes disabled', 'Hordas desativadas'), 'HordeCooldown': ('Native horde cooldown', 'Intervalo nativo entre hordas'),
    'Incompatible': ('Unavailable native event interface', 'Interface de evento nativo indisponível'),
    'InternalError': ('Director error; see log', 'Erro no diretor; consulte o log'),
}
events = {'xp': ('XP', 'XP'), 'money': ('Money', 'Dinheiro'), 'box': ('Mystery Box Hunt', 'Caçada às caixas misteriosas'),
          'blood': ('Evil Blood', 'Sangue maligno'), 'soul': ('Evil Souls', 'Almas malignas'),
          'marrow': ('Evil Marrow', 'Medula maligna'), 'bile': ('Evil Bile', 'Bile maligna'), 'horde': ('Horde', 'Horda'),
          'drops': ('Material and money drops', 'Drops de materiais e dinheiro')}
for event, name in events.items():
    strings['Event_' + event] = name
    if event in ('horde', 'drops'):
        continue
    for suffix, caption in {
        'Enabled': ('enabled', 'ativado'), 'Weight': ('selection weight (0 = never)', 'peso no sorteio (0 = nunca)'),
        'Value': ('multiplier' if event in ('xp', 'money') else 'drop chance (%)', 'multiplicador' if event in ('xp', 'money') else 'chance de drop (%)'),
        'DurationMin': ('minimum duration (real minutes)', 'duração mínima (minutos reais)'),
        'DurationMax': ('maximum duration (real minutes)', 'duração máxima (minutos reais)'),
    }.items():
        labels[event + '_' + suffix] = (name[0] + ': ' + caption[0], name[1] + ': ' + caption[1])
for stage in range(1, 6):
    labels['ThreatChance' + str(stage)] = (f'Danger stage {stage}: threat chance (%)', f'Estágio de perigo {stage}: chance de ameaça (%)')

tips = {
    'Enabled': ('Off by default. Stops new director events only; existing events end normally.', 'Desativado por padrão. Interrompe apenas novos eventos do diretor; eventos existentes terminam normalmente.'),
    'Preset': ('Intervals count real played minutes after an event ends. Offline, empty and paused sessions do not accumulate events. Interval edits apply a new countdown.', 'Intervalos contam minutos reais jogados após o evento terminar. Períodos offline, vazios ou pausados não acumulam eventos. Alterar o intervalo inicia uma nova contagem.'),
    'IntervalMin': ('Used only by the Custom preset. Reversed bounds are automatically ordered.', 'Usado apenas no preset Personalizado. Limites invertidos são ordenados automaticamente.'),
    'IntervalMax': ('Used only by the Custom preset. Reversed bounds are automatically ordered.', 'Usado apenas no preset Personalizado. Limites invertidos são ordenados automaticamente.'),
    'HordeEnabled': ('Does not disable native kill-triggered hordes. Director hordes respect native size, duration and cooldown.', 'Não desativa hordas nativas por abates. Hordas do diretor respeitam tamanho, duração e intervalo nativos.'),
    'ExtractionProtection': ('Optional integration. Unknown Extraction Mode states block director attacks safely.', 'Integração opcional. Estados desconhecidos do Extraction Mode bloqueiam ataques do diretor por segurança.'),
    'NeighborRadius': ('A vulnerable neighbor also protects the selected target. Zero disables the proximity check.', 'Um vizinho vulnerável também protege o alvo selecionado. Zero desativa a verificação de proximidade.'),
    'NightEventsEnabled': ('Off by default. Each night, the configured weights select one level that increases container loot chances and the chance for zombies to become sprinters.', 'Desativado por padrão. A cada noite, os pesos configurados sorteiam um nível que aumenta a chance de loot nos containers e a chance de zumbis virarem sprinters.'),
    'NightEventsChance': ('When Night Events are enabled, this is the chance that the event occurs on each night. The level is rolled only when the event occurs.', 'Com os eventos noturnos ativados, esta é a chance de o evento ocorrer a cada noite. O nível só é sorteado quando o evento acontece.'),
}
for level in range(1, 5):
    tips[f'NightLevel{level}Weight'] = ('Weights are normalized automatically. If every level weight is 0, Level 1 is selected.', 'Os pesos são normalizados automaticamente. Se todos forem 0, o nível 1 será selecionado.')
    tips[f'NightLevel{level}LootBonus'] = ('Percent added to the original item spawn chance. A 50% bonus changes a 20% chance to 30%.', 'Percentual somado à chance original do item. Um bônus de 50% transforma uma chance de 20% em 30%.')
    tips[f'NightLevel{level}SprinterPercentage'] = ('Chance for each zombie to become a sprinter during the night. Selected zombies return to their original speed during the day.', 'Chance de cada zumbi virar sprinter durante a noite. Os selecionados voltam à velocidade original durante o dia.')

for language, index in [('EN', 0), ('PTBR', 1)]:
    folder = LUA / 'shared/Translate' / language
    folder.mkdir(parents=True, exist_ok=True)
    ui = {'UI_PRPGE_SPDO_' + key: value[index] for key, value in strings.items()}
    sandbox = {'Sandbox_SPDO_Orchestrator': 'Survivor PDA Orchestrator'}
    for _, d in config.definitions.items():
        key, name = d.key, d.key[5:]
        label = labels[name][index]
        tip = tips.get(name, (label, label))[index]
        ui['UI_PRPGE_Config_' + key] = label
        ui['UI_PRPGE_ConfigTip_' + key] = tip
        sandbox['Sandbox_' + key] = label
        sandbox['Sandbox_' + key + '_tooltip'] = tip
        if d.choices:
            for i, choice in d.choices.items():
                sandbox['Sandbox_' + key + '_option' + str(i)] = strings[choice[5:]][index]
    for file, values in [('UI.json', ui), ('Sandbox.json', sandbox)]:
        (folder / file).write_text(json.dumps(values, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
lines = ['VERSION = 1,', '']
for _, d in config.definitions.items():
    boolean = isinstance(d.default, bool)
    kind = 'boolean' if boolean else 'enum' if d.choices else 'double' if d.decimal else 'integer'
    value = str(d.default).lower() if boolean else str(d.default)
    lines.extend([f'option ProjectRPGExpanded.{d.key}', '{', f'    type = {kind},', '    page = SPDO_Orchestrator,',
                  f'    translation = {d.key},', f'    default = {value},'])
    if d.choices:
        lines.append(f'    numValues = {len(d.choices)},')
    elif not boolean:
        lines.extend([f'    min = {d.min},', f'    max = {d.max},'])
    lines.extend(['}', ''])
(MEDIA / 'sandbox-options.txt').write_text('\n'.join(lines), encoding='utf-8')
metadata = '\n'.join(['name=Survivor PDA Orchestrator', 'id=SurvivorPDAOrchestrator', 'author=Maeiro',
    'description=An adaptive event director for Survivor PDA (ProjectRPGExpanded), including configurable Night Events.',
    'modversion=0.2.0', 'versionMin=42.21.0', 'require=ProjectRPGExpanded,ZombieBuddy',
    'loadModAfter=ProjectRPGExpanded,ExtractionMode,ZombieBuddy', ''])
for file in [MOD / 'mod.info', MOD / '42/mod.info']:
    java_metadata = metadata
    if file.parent.name == '42':
        java_metadata += 'javaJarFile=media/java/client/SurvivorPDAOrchestrator.jar\njavaPkgName=maeiro.survivorpdaorchestrator\nZBVersionMin=2.3.4\n'
    file.write_text(java_metadata, encoding='utf-8')
print(f'Generated {len(config.definitions)} sandbox options and EN/PTBR translations.')
