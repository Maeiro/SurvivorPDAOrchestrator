local ok, err = pcall(require, 'SPDO/Config')
if not ok then print('[Survivor PDA Orchestrator] Settings unavailable: ' .. tostring(err)) end
