// Solo para la prueba de integración; nunca contacta OpenRouter.
process.env.OPENROUTER_API_KEY = 'test-key-not-real';
process.env.CHEQUI_BRIDGE_TOKEN = 'test-token-12345678901234567890';
global.fetch = async () => new Response(JSON.stringify({choices:[{message:{tool_calls:[{function:{name:'consultar_gastos',arguments:'{"periodo":"hoy","metodo":"todos","vista":"total","categoria":"todas"}'}}]}}]}),{status:200});
require('./server.cjs');
