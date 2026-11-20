'use strict';
const http = require('node:http');
const crypto = require('node:crypto');
const key = process.env.OPENROUTER_API_KEY;
const token = process.env.CHEQUI_BRIDGE_TOKEN;
if (!key || !token || token.length < 24) { console.error('Configura OPENROUTER_API_KEY y CHEQUI_BRIDGE_TOKEN (al menos 24 caracteres).'); process.exit(1); }
const tools = [
 {type:'function',function:{name:'consultar_gastos',description:'Consulta registros ficticios de la sesión activa en el teléfono. Nunca inventes cifras.',parameters:{type:'object',properties:{periodo:{type:'string',enum:['hoy','semana','mes','todos']},metodo:{type:'string',enum:['todos','efectivo','tarjeta','debito','credito','transferencia']},vista:{type:'string',enum:['total','ultimos']},categoria:{type:'string',enum:['todas','Alimentos','Insumos','Transporte','Servicios','Operación','Otros']}},required:['periodo','metodo','vista','categoria'],additionalProperties:false}}},
 {type:'function',function:{name:'preparar_gasto',description:'Abre un formulario editable. No guarda ningún gasto.',parameters:{type:'object',properties:{monto:{type:'string',description:'Importe decimal sin símbolo; vacío si falta.'},concepto:{type:'string'},comercio:{type:'string'},fecha:{type:'string',description:'Fecha explícita ISO AAAA-MM-DD, o vacío si no se conoce.'},categoria:{type:'string',enum:['Alimentos','Insumos','Transporte','Servicios','Operación','Otros','']},metodo:{type:'string',enum:['Efectivo','Tarjeta de débito','Tarjeta de crédito','Transferencia','Billetera digital','Desconocido']}},required:['monto','concepto','comercio','fecha','categoria','metodo'],additionalProperties:false}}}
];
const system = 'Eres Chequi, asistente en español para una demostración con datos ficticios. Para consultas de gastos usa consultar_gastos. Para registrar usa preparar_gasto: no guardes, no inventes campos. Tarjeta sin especificar es Desconocido. Nunca calcules ni inventes saldos. Responde brevemente si no se solicita ninguna función.';
function respond(res, status, obj) { res.writeHead(status, {'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'}); res.end(JSON.stringify(obj)); }
const server = http.createServer(async (req,res) => {
  const header = req.headers['x-chequi-token']; const supplied = Buffer.from(typeof header === 'string' ? header : ''); const expected = Buffer.from(token);
  if (supplied.length !== expected.length || !crypto.timingSafeEqual(supplied,expected)) return respond(res,401,{error:'No autorizado'});
  if (req.method !== 'POST' || req.url !== '/chat') return respond(res,404,{error:'No encontrado'});
  let body = ''; try { for await (const chunk of req) { body += chunk; if (Buffer.byteLength(body)>16384) return respond(res,413,{error:'Solicitud demasiado grande'}); }
    const data = JSON.parse(body); if (!Array.isArray(data.messages) || data.messages.length < 1 || data.messages.length > 10 || data.messages.some(m => !m || !['user','assistant'].includes(m.role) || typeof m.content !== 'string' || m.content.length > 1500)) return respond(res,400,{error:'Mensaje inválido'});
    const upstream = await fetch('https://openrouter.ai/api/v1/chat/completions', {method:'POST', headers:{Authorization:`Bearer ${key}`,'Content-Type':'application/json'},body:JSON.stringify({model:'nvidia/nemotron-3.5-lightning:free',messages:[{role:'system',content:system},...data.messages],tools,tool_choice:'auto',reasoning:{enabled:false},max_tokens:600}),signal:AbortSignal.timeout(45000)});
    if (!upstream.ok) return respond(res, upstream.status === 429 ? 429 : 502,{error:upstream.status === 429 ? 'Se agotó el límite temporal del proveedor.' : 'El proveedor no pudo procesar la solicitud.'});
    const payload = await upstream.json(); const message = payload.choices?.[0]?.message; if (!message) return respond(res,502,{error:'Respuesta incompleta del proveedor.'});
    const calls = message.tool_calls; if (Array.isArray(calls) && calls.length) { if (calls.length !== 1 || !['consultar_gastos','preparar_gasto'].includes(calls[0]?.function?.name)) return respond(res,502,{error:'Solicitud de función no válida.'}); return respond(res,200,{tool:calls[0].function.name,arguments:calls[0].function.arguments}); }
    return respond(res,200,{message:typeof message.content === 'string' ? message.content.slice(0,2000) : ''});
  } catch (_) { if (!res.headersSent) respond(res,502,{error:'No se pudo contactar al proveedor.'}); }
});
server.listen(8787,'127.0.0.1',() => console.log('Chequi disponible solo en 127.0.0.1:8787'));
module.exports = server;
