'use strict';
process.env.OPENROUTER_API_KEY = 'test-key-not-real';
process.env.CHEQUI_BRIDGE_TOKEN = 'test-token-12345678901234567890';
const realFetch = global.fetch;
let forwarded;
global.fetch = async (url, options) => { forwarded = JSON.parse(options.body); return new Response(JSON.stringify({choices:[{message:{tool_calls:[{function:{name:'consultar_gastos',arguments:'{"periodo":"hoy","metodo":"todos","vista":"total"}'}}]}}]}),{status:200}); };
const server = require('./server.cjs');
const assert = require('node:assert/strict');
(async () => {
  await new Promise(resolve => server.once('listening',resolve));
  let response = await realFetch('http://127.0.0.1:8787/chat',{method:'POST',headers:{'Content-Type':'application/json','x-chequi-token':'wrong'},body:'{}'});
  assert.equal(response.status,401);
  response = await realFetch('http://127.0.0.1:8787/chat',{method:'POST',headers:{'Content-Type':'application/json','x-chequi-token':process.env.CHEQUI_BRIDGE_TOKEN},body:JSON.stringify({messages:[{role:'user',content:'¿Cuánto gasté hoy?'}]})});
  assert.equal(response.status,200); assert.equal((await response.json()).tool,'consultar_gastos'); assert.equal(forwarded.model,'nvidia/nemotron-3.5-lightning:free'); assert.equal(forwarded.messages.length,2);
  console.log('Prueba del puente: correcta');
})().catch(e=>{console.error(e); process.exitCode=1;}).finally(()=>server.close());
