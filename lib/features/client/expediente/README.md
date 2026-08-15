# features/client/expediente

Los documentos que el cliente **sube**: qué se le pide, en qué estatus está cada
uno y todo el flujo de carga.

No confundir con `features/client/facturacion`, que son los documentos que la
empresa **entrega** al cliente (facturas, contratos). Son dos direcciones del
mismo menú y por eso son dos puertos distintos.

```
ports/expediente_port.dart          ExpedientePort (listar · analizar · subir)
adapters/expediente_adapter.dart    ExpedienteAdapter - único con supabase_flutter
providers/expediente_providers.dart expedientePortProvider · identityFileProvider
layouts/expediente_layout.dart      ancho, scroll, volver y la tarjeta
screens/expediente_screen.dart      45 líneas: compone layout + componentes
components/expediente_documentos.dart  la lista + TODO el flujo de carga (estado)
components/expediente_slot_row.dart    fila de un documento
components/cuenta_bancaria_row.dart    fila estructurada de cuenta bancaria
components/expediente_card.dart        tarjeta del Perfil (la consume perfil_screen)
services/expediente_grupos.dart     grupos PF/PM, ids de tipo y las notas
services/campos_documento.dart      qué datos alimenta cada documento
services/archivo_pdf.dart           magic bytes, límite de tamaño y selector
```

## El flujo de carga, en una sola hoja

```
[ tipo de documento ]          ┌──────────────┐
[ zona de carga    ]  ──────►  │ vista previa │
        │  adjunta             └──────────────┘
        ▼
[ archivo ] + [ campos extraídos o por capturar ]
        │  Guardar
        ▼
[ acepta condiciones ] ──► subir
```

1. `showSDocUpload` (en `lib/ui/`) es la hoja. Antes de adjuntar, la zona de
   carga ocupa el centro de la columna; al adjuntar se encoge a una línea y su
   lugar lo toman los campos. La previsualización vive a la derecha todo el
   tiempo (arriba en pantalla angosta).
2. `archivo_pdf` comprueba los **magic bytes** `%PDF-`, no la extensión. Un
   `.jpg` renombrado a `.pdf` se rechaza ahí sin gastar el viaje; el backend lo
   vuelve a comprobar de todos modos.
3. `onAnalizar` extrae y valida **sin guardar nada**, y devuelve qué campos
   pedir. Si el slot admite varias formas del mismo documento (INE **o**
   pasaporte) se elige cuál primero: subir las dos deja dos identificaciones
   vigentes y verificación no sabe cuál manda. Cambiar de tipo suelta el
   archivo adjunto.
4. Al **Guardar** sale `showSConfirm` con las condiciones del documento (PDF,
   legible, completo). Van ahí y no junto a la zona de carga a propósito: ahí
   se leen de pasada, en el diálogo hay que aceptarlas, y así queda claro que
   un rechazo lo resuelve el cliente volviendo a cargar.
5. En escritorio, `Esc` cancela la hoja.

**Un PDF sin texto NO es un rechazo.** Se acepta y queda en revisión manual;
los campos salen vacíos y **requeridos**, con el aviso de que hay que
capturarlos. El rechazo se reserva para lo que el cliente puede arreglar solo:
no es un PDF, o el documento está vencido.

## Qué campos pide cada documento

`services/campos_documento.dart`. Documento que no aparece ahí es **solo
evidencia**: se sube, se ve y ya. No se le inventan campos al cliente.

| Documento | Campos | Obligatorios |
|---|---|---|
| Acta de nacimiento (1), CURP (5) | nombre, CURP, fecha de nacimiento, sexo | los cuatro |
| CSF (6) | RFC, nombre, nombre comercial, CURP, régimen, CP, calle, núm. ext, núm. int, colonia, actividad económica | RFC, nombre, régimen, CP, calle, colonia |
| Domicilio (8), matrimonio (11), identificación (63/4), y todos los de PM | ninguno | - |

Qué bloquea sale de las mismas reglas del back office
(`sozu-admin/src/utils/fiscalDataValidation.ts` → `isFiscalDataComplete`): RFC,
régimen, calle, colonia y CP bloquean; los números exterior e interior no.

## La previsualización rasteriza UNA página

`SPdfPreview` convierte la página actual a imagen y la pinta con
`Image.memory`. El visor con scroll continuo (`PdfViewPinch`) rasterizaba todas
las páginas mientras el usuario leía: en web eso traba la pestaña varios
segundos, y su scroll propio se peleaba con el de la hoja (rodar la rueda hacía
saltar la modal al inicio). La misma previsualización la usa la carátula de
cuenta bancaria en `profile/components/perfil_sheets.dart`.

## Qué se pide y en qué orden

El orden lo manda el backend (`SLOTS_PF` / `SLOTS_PM` de `cliente-expediente`) y
la pantalla lo respeta tal cual: pinta los grupos en el orden que llegan y, dentro
de cada uno, los slots en el orden que llegan.

**Persona física** · Documentos personales: identificación oficial (INE o
pasaporte) · acta de nacimiento · CURP · constancia de situación fiscal ·
comprobante de domicilio · acta de matrimonio. Después, Datos bancarios.

**Persona moral**
1. *Documentos de la empresa*: CSF · acta constitutiva · registro público de
   comercio · comprobante de domicilio · **Otros documentos** (anexos, varios).
2. *Representante legal*: los seis de persona física + poder notarial.
3. *Accionista mayoritario (más del 20%)*: los seis de persona física.
4. *Beneficiario controlador*: su documento.
5. *Datos bancarios*.

Los seis documentos de persona física salen de **una sola** lista en el backend
(`slotsPersonaFisica`), que reusan el titular, el representante y el accionista:
es la misma lista, cambia de quién son.

El nombre que ve el cliente es el `label` del slot, NO `tipos_documento.nombre`:
el del catálogo es el nombre legal ("INE completo (frente y reverso)").

### El árbol es recursivo y solo para en una persona física

Una persona ligada que es **empresa** no es una hoja: su pantalla vuelve a ser
una portada (sus documentos de empresa + su representante legal + sus
accionistas) y desde ahí se sigue bajando. La rama se detiene en la primera
persona **física**, que es la que pide beneficiario controlador; parar antes
deja el expediente incompleto para efectos fiscales.

```
Titular PM
├─ Documentos de la empresa · Otros documentos
├─ Representante legal · Ana (PF)          → sus 6 documentos. Fin de la rama.
└─ Accionista · Empresa Prueba (PM, 26%)   → OTRA portada
   ├─ Documentos de la empresa
   ├─ Representante legal · …              → hasta dar con personas físicas
   └─ Accionistas · …
```

Quién decide: `PersonaExpedienteScreen`. Con `rol: 'empresa'` pinta la lista de
documentos y nada más (sus personas ya salen en la portada desde la que se
entró); con una PM ligada pinta `ExpedienteModo.auto`, que resuelve a portada.

⚠️ **`esMoral` viaja como parámetro**, desde la tarjeta que abrió la pantalla.
Antes el tipo salía del PERFIL, o sea del titular: a una persona física colgada
de una empresa se le pedían documentos de empresa. El mismo parámetro gobierna
qué campos se le piden al subir un documento.

### Registrar a una persona no sube nada

El alta (`components/expediente_personas.dart`) pide **nombre, correo y
teléfono**, y con eso la persona queda creada. No hay zona de carga ni
previsualización: pedir el PDF ahí obligaba a tenerlo a la mano para poder
registrar a alguien. Al guardar sale el aviso de que falta su documentación y
se entra directo a su ficha, que es donde vive la lista de lo que se le pide.

Los porcentajes de los accionistas **no pueden sumar más de 100**. La hoja
muestra cuánto queda disponible y lo valida, pero la regla de verdad es la de
la edge function: dos pestañas abiertas registran 60% y 60% sin enterarse.
Contrato en `Ejecuciones_manuales/2026-08-15_EF_alta_persona_datos_minimos.md`.

El vínculo vive en `personas_relacionadas` (`id_persona` · `id_persona_relacion`
· `id_tipo_relacion` · `porcentaje`), con un trigger que rechaza los ciclos:
sin él, dos empresas accionistas la una de la otra cuelgan el recorrido del
árbol. `tipos_relacion`: Representante Legal = 1, Accionista = 15. Aplicado y
verificado en producción el 2026-08-15.

## Anexos: un slot con varios documentos

"Otros documentos" es el único slot `multiple`. Trae `documentos: [...]` y la
pantalla pinta **una fila por anexo** más una para agregar otro:

- Subir en la fila de agregar crea un anexo nuevo y no toca los demás.
- Subir dentro de la fila de un anexo lo reemplaza: viaja `doc_id` y solo ese se
  expira.
- Ninguno es obligatorio, así que no bloquean el expediente.

La **descripción** de cada anexo es lo que los distingue y viaja aparte de los
campos del perfil: `documentos.descripcion`, con el tipo 69 ("Otros
documentos"). Los dos existen en producción, verificado el 2026-08-15.

## Persona física / persona moral

Qué se le pide a cada quién lo decide el backend y llega en `grupos` +
`slot.grupo`. La lista canónica vive en
`sozu-admin/src/utils/expediente-obligatorios.ts` (`GRUPOS_PF` / `GRUPOS_PM`),
que es lo que ya consumen escrituración, jurídico, socio bancario, notaría y
cobranza. Si cambia, cambia ahí primero.

`ExpedienteGrupos.construir` cae a los dos grupos de persona física mientras el
backend no mande `grupos`: sin ese respaldo la pantalla quedaría en una sola
lista sin títulos con la edge function actual. En ese mismo respaldo,
`_fusionarIdentidad` junta INE frente (2), INE reverso (3) y pasaporte (4) en
una sola fila **Identificación oficial** con las dos opciones vigentes: INE
completo (63) o pasaporte (4).

El tipo 63 ("INE completo (frente y reverso)") ya existe en `tipos_documento` y
en el `SLOTS` de la edge function desplegada, así que subir INE funciona. El
mapeo de `tipo_invalido` a un mensaje concreto se queda: si un despliegue vuelve
a quedar atrás, el cliente lee el motivo en vez de un "intenta de nuevo".

En persona moral, los documentos del representante legal son de **otra
persona**. Si no está ligada, el grupo se muestra igual pero deshabilitado, con
el motivo escrito: el cliente tiene que ver que su expediente está incompleto y
por qué (11 de 27 clientes PM en producción están así).

## La identidad del slot es `key`, no `tipo_id`

En persona moral los tipos 6 (CSF) y 8 (domicilio) aparecen **dos veces**, una
de la empresa y otra del representante (`csf_empresa` vs `csf_rep`). Resolver
por `tipo_id` guarda la CSF del representante en la empresa.

## Contrato del backend

La reescritura v2 de `cliente-expediente` (persona física / moral y la acción
`analizar`) **ya está desplegada**, junto con `personas.actividad_economica` y
`personas.id_estado_civil`: verificado en producción el 2026-08-10. Su `.md` de
ejecución se borró al aplicarse; el contrato vigente es el código de
`sozu-edge-functions`.

Todos los campos nuevos son **aditivos**: sin ellos la pantalla se comporta como
antes, así que backend y frontend no necesitan desplegarse a la vez. El orden
seguro es backend primero.
