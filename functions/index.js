const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const DEFAULT_CONSULTATION_TIME_MINUTES = 30;
const SAFETY_MARGIN_MINUTES = 10;

const isValidTimestamp = (value) => {
  return value && value instanceof admin.firestore.Timestamp;
};

exports.getWaitingTime = functions
  .runWith({
      enforceAppCheck: true, // Rejeita requisições com tokens do App Check ausentes ou inválidos.
  })
  .https.onCall(async (data, context) => {
    try {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          "unauthenticated",
          "O usuário não está autenticado."
        );
      }

      const uid = context.auth.uid;
      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Perfil de usuário não encontrado.");
      }

      const userData = userDoc.data();
      const { cpf: userCpf, name: userName } = userData;

      if (!userCpf || !userName) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Dados do perfil do usuário estão incompletos."
        );
      }

      const now = new Date();
      const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const endOfDay = new Date(startOfDay.getTime() + 24 * 60 * 60 * 1000);

      const appointmentQuery = await db
        .collection("appointments")
        .where("patientCpf", "==", userCpf)
        .where("appointmentDate", ">=", startOfDay)
        .where("appointmentDate", "<", endOfDay)
        .limit(1)
        .get();

      if (appointmentQuery.empty) {
        return { userName, appointment: null, queuePosition: null, estimatedTime: null, debugInfo: "Nenhuma consulta encontrada para hoje." };
      }

      const appointmentDoc = appointmentQuery.docs[0];
      const appointmentData = appointmentDoc.data();

      if (!isValidTimestamp(appointmentData.appointmentDate)) {
        throw new functions.https.HttpsError("internal", "Formato de data da consulta inválido.");
      }
      
      const appointmentResult = {
        patientName: appointmentData.patientName,
        date: appointmentData.appointmentDate.toDate().toISOString(),
        time: appointmentData.timeSlot,
        checkInTime: isValidTimestamp(appointmentData.checkInTime) ? appointmentData.checkInTime.toDate().toISOString() : null,
        startConsultationTime: isValidTimestamp(appointmentData.startConsultationTime) ? appointmentData.startConsultationTime.toDate().toISOString() : null,
        endConsultationTime: isValidTimestamp(appointmentData.endConsultationTime) ? appointmentData.endConsultationTime.toDate().toISOString() : null,
      };

      // Se a consulta já começou, o tempo de espera é 0.
      if (appointmentData.startConsultationTime) {
        return { userName, appointment: appointmentResult, queuePosition: 0, estimatedTime: 0, debugInfo: "Consulta em andamento." };
      }

      // Calcula o tempo médio de atendimento com base no histórico
      let dynamicAverageServiceTime = DEFAULT_CONSULTATION_TIME_MINUTES;
      const historySnapshot = await db
        .collection("appointments")
        .where("endConsultationTime", ">", admin.firestore.Timestamp.fromMillis(0))
        .orderBy("endConsultationTime", "desc")
        .limit(30)
        .get();

      if (!historySnapshot.empty) {
        let totalDurationMinutes = 0;
        let count = 0;
        historySnapshot.docs.forEach((doc) => {
          const pastAppointment = doc.data();
          if (isValidTimestamp(pastAppointment.startConsultationTime) && isValidTimestamp(pastAppointment.endConsultationTime)) {
            const startTime = pastAppointment.startConsultationTime.toDate();
            const endTime = pastAppointment.endConsultationTime.toDate();
            if (endTime > startTime) {
              totalDurationMinutes += (endTime.getTime() - startTime.getTime()) / 60000;
              count++;
            }
          }
        });
        if (count > 0) {
          dynamicAverageServiceTime = totalDurationMinutes / count;
        }
      }

      // =================== LÓGICA DE FILA SIMPLIFICADA ===================
      // Cria uma fila única com todos os pacientes do dia que ainda não foram atendidos,
      // ordenada pelo horário agendado.
      const queueSnapshot = await db.collection("appointments")
        .where("appointmentDate", ">=", startOfDay)
        .where("appointmentDate", "<", endOfDay)
        .where("startConsultationTime", "==", null) // Apenas quem não foi atendido
        .orderBy("appointmentDate")
        .orderBy("timeSlot")
        .get();
      
      const queuePatients = queueSnapshot.docs.map(doc => doc.data());
      const userQueuePosition = queuePatients.findIndex(p => p.patientCpf === userCpf) + 1;

      if (userQueuePosition <= 0) {
        return { 
          userName, 
          appointment: appointmentResult, 
          queuePosition: null, 
          estimatedTime: null, 
          debugInfo: { 
            message: "Usuário não encontrado na fila de agendamentos.", 
            cpfDoUsuarioProcurado: userCpf,
          } 
        };
      }
      
      // Calcula o tempo restante do paciente em atendimento (se houver)
      let currentConsultationRemainingTime = 0;
      const inProgressSnapshot = await db
        .collection("appointments")
        .where("startConsultationTime", ">", admin.firestore.Timestamp.fromMillis(0))
        .where("endConsultationTime", "==", null)
        .orderBy("startConsultationTime")
        .limit(1)
        .get();

      if (!inProgressSnapshot.empty) {
        const inProgressData = inProgressSnapshot.docs[0].data();
        if (isValidTimestamp(inProgressData.startConsultationTime)) {
          const startTime = inProgressData.startConsultationTime.toDate();
          const timeElapsedMinutes = (now.getTime() - startTime.getTime()) / 60000;
          const remainingTime = dynamicAverageServiceTime - timeElapsedMinutes;
          currentConsultationRemainingTime = Math.max(0, remainingTime);
        }
      }
      
      // Calcula o tempo de espera com base na posição na fila única
      const waitingQueueTime = (userQueuePosition - 1) * dynamicAverageServiceTime;
      const totalEstimatedTime = Math.ceil(
        currentConsultationRemainingTime + waitingQueueTime + SAFETY_MARGIN_MINUTES
      );

      return {
        userName,
        appointment: appointmentResult,
        queuePosition: userQueuePosition,
        estimatedTime: totalEstimatedTime,
        debugInfo: {
          queueName: "Fila por Horário Agendado",
          avgServiceTime: dynamicAverageServiceTime,
          currentConsultationRemainingTime,
          waitingQueueTime,
          safetyMargin: SAFETY_MARGIN_MINUTES,
        }
      };
    } catch (error) {
      console.error("Erro detalhado em getWaitingTime:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError("internal", error.message || "Ocorreu um erro interno.");
    }
  });
