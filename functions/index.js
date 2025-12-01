/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// AGREGAMOS 'onDocumentDeleted' A LOS IMPORTS
const { onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

// Inicializamos la app de admin
if (admin.apps.length === 0) {
    admin.initializeApp();
}

// --- FUNCIÓN 1: NOTIFICACIONES (YA EXISTÍA) ---
exports.enviarNotificacionClase = onDocumentCreated("notificaciones/{notificacionId}", async (event) => {

    const snapshot = event.data;
    if (!snapshot) return;

    const datos = snapshot.data();

    if (!datos.titulo || !datos.cuerpo || !datos.claseId) return;

    let claseIdString;
    try {
        claseIdString = datos.claseId.id;
    } catch (e) {
        claseIdString = datos.claseId;
    }

    const tema = `clase_${claseIdString}`;
    console.log(`Intentando enviar notificación al tema: ${tema}`);

    const mensaje = {
        notification: {
            title: datos.titulo,
            body: datos.cuerpo,
        },
        topic: tema,
        data: {
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            notificacionId: event.params.notificacionId
        }
    };

    try {
        await admin.messaging().send(mensaje);
        console.log("¡Notificación enviada con éxito!");
    } catch (error) {
        console.error("Error al enviar notificación:", error);
    }
});

// --- FUNCIÓN 2: SINCRONIZACIÓN DE BORRADO (NUEVA) ---
// Esta función se dispara automáticamente cuando borras un documento en 'usuario'
exports.eliminarUsuarioAuth = onDocumentDeleted("usuario/{userId}", async (event) => {
    const userId = event.params.userId;

    console.log(`Detectado borrado de documento usuario/${userId}. Procediendo a borrar cuenta de Auth...`);

    try {
        // Usamos el SDK de Admin para borrar al usuario del sistema de Autenticación
        await admin.auth().deleteUser(userId);
        console.log(`✅ Cuenta de Auth para ${userId} eliminada exitosamente.`);
    } catch (error) {
        if (error.code === 'auth/user-not-found') {
             console.log(`El usuario ${userId} ya no existía en Auth.`);
        } else {
             console.error("❌ Error al eliminar usuario de Auth:", error);
        }
    }
});