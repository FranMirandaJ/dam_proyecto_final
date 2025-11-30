/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

// Inicializamos la app de admin para poder mandar mensajes
admin.initializeApp();

exports.enviarNotificacionClase = onDocumentCreated("notificaciones/{notificacionId}", async (event) => {

    // En V2, el 'snapshot' (el documento creado) viene dentro de event.data
    const snapshot = event.data;

    // Si no hay datos, salimos
    if (!snapshot) {
        console.log("No se encontraron datos asociados al evento.");
        return;
    }

    // 1. Obtenemos los datos del documento
    const datos = snapshot.data();

    // Verificación de seguridad
    if (!datos.titulo || !datos.cuerpo || !datos.claseId) {
        console.log("Faltan datos (titulo, cuerpo o claseId) para enviar la notificación");
        return;
    }

    // 2. Extraemos el ID de la clase
    // Asumimos que es Reference. Si fuera string directo, borrar el .id
    let claseIdString;
    try {
        claseIdString = datos.claseId.id;
    } catch (e) {
        // Fallback por si acaso lo guardaste como texto simple y no Referencia
        claseIdString = datos.claseId;
    }

    // 3. Definimos el Tema (Topic)
    const tema = `clase_${claseIdString}`;
    console.log(`Intentando enviar notificación al tema: ${tema}`);

    // 4. Construimos el mensaje
    const mensaje = {
        notification: {
            title: datos.titulo,
            body: datos.cuerpo,
        },
        topic: tema,
        data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            notificacionId: event.params.notificacionId // ID del documento
        }
    };

    // 5. Enviamos a FCM
    try {
        await admin.messaging().send(mensaje);
        console.log("¡Notificación enviada con éxito!");
    } catch (error) {
        console.error("Error al enviar notificación:", error);
    }
});