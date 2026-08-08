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
| CSF (6) | RFC, nombre, nombre comercial, CURP, régimen, CP, calle, núm. ext, núm. int, colonia | RFC, nombre, régimen, CP, calle, colonia |
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

⚠️ Con la edge function ACTUAL el tipo 63 no existe en su `SLOTS`, así que
subir INE devuelve `tipo_invalido` y solo el pasaporte funciona. Está mapeado a
un mensaje que lo dice en vez de a un "intenta de nuevo". Se resuelve al
desplegar el backend nuevo.

En persona moral, los documentos del representante legal son de **otra
persona**. Si no está ligada, el grupo se muestra igual pero deshabilitado, con
el motivo escrito: el cliente tiene que ver que su expediente está incompleto y
por qué (11 de 27 clientes PM en producción están así).

## La identidad del slot es `key`, no `tipo_id`

En persona moral los tipos 6 (CSF) y 8 (domicilio) aparecen **dos veces**, una
de la empresa y otra del representante (`csf_empresa` vs `csf_rep`). Resolver
por `tipo_id` guarda la CSF del representante en la empresa.

## Contrato del backend

Está en `Ejecuciones_manuales/2026-08-07_EF_cliente-expediente.md` (gitignored),
para el repo `sozu-edge-functions`. La columna que le falta a la base va aparte
en `2026-08-07_BD_actividad_economica.md` y es opcional.

Todos los campos nuevos son **aditivos**: sin ellos la pantalla se comporta como
antes, así que backend y frontend no necesitan desplegarse a la vez. El orden
seguro es backend primero.
