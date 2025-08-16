import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

admin.initializeApp();

// =================== FUNÇÃO DE TEMPO DE ESPERA ===================
export const getWaitingTime = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "A função deve ser chamada por um utilizador autenticado.");
  }
  
  const uid = request.auth.uid;
  const firestore = admin.firestore();
  // ... (toda a lógica da função de tempo de espera que já tínhamos)
  try {
    const userDoc = await firestore.collection("users").doc(uid).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "Utilizador não encontrado.");
    }
    const userData = userDoc.data();
    const userName = userData?.name ?? "Utilizador";
    const userCpf = userData?.cpf;
    if (!userCpf) {
      return {userName, estimatedTime: null, queuePosition: null, appointment: null};
    }
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    const snapshot = await firestore.collection("appointments")
      .where("appointmentDate", ">=", startOfToday)
      .where("appointmentDate", "<", endOfToday)
      .orderBy("appointmentDate")
      .get();
    const allAppointmentsToday = snapshot.docs;
    let averageServiceTime = 20.0;
    const finishedAppointments = allAppointmentsToday.filter((doc) =>
      doc.data().startConsultationTime && doc.data().endConsultationTime,
    );
    if (finishedAppointments.length > 0) {
      let totalServiceMinutes = 0;
      finishedAppointments.forEach((doc) => {
        const startTime = doc.data().startConsultationTime.toDate();
        const endTime = doc.data().endConsultationTime.toDate();
        totalServiceMinutes += (endTime.getTime() - startTime.getTime()) / (1000 * 60);
      });
      averageServiceTime = totalServiceMinutes / finishedAppointments.length;
    }
    const userAppointmentDoc = allAppointmentsToday
      .find((doc) => doc.data().patientCpf === userCpf);
    if (!userAppointmentDoc) {
      return {userName: userName, appointment: null};
    }
    const appointmentData = userAppointmentDoc.data();
    let estimatedTime: number | null = null;
    let queuePosition: number | null = null;
    if (appointmentData.checkInTime && !appointmentData.startConsultationTime) {
      const peopleAhead = allAppointmentsToday.filter((doc) => {
        const data = doc.data();
        return data.checkInTime &&
          !data.startConsultationTime &&
          data.appointmentDate.toDate() < appointmentData.appointmentDate.toDate();
      });
      queuePosition = peopleAhead.length + 1;
      let waitTime = peopleAhead.length * averageServiceTime;
      const inProgressDoc = allAppointmentsToday.find((doc) =>
        doc.data().startConsultationTime && !doc.data().endConsultationTime,
      );
      if (inProgressDoc) {
        const progressStartTime = inProgressDoc.data().startConsultationTime.toDate();
        const timeInProgress = (now.getTime() - progressStartTime.getTime()) / (1000 * 60);
        const remainingTime = averageServiceTime - timeInProgress;
        waitTime += (remainingTime > 0 ? remainingTime : 0);
      }
      estimatedTime = Math.round(waitTime);
    }
    return {
      userName: userName,
      estimatedTime: estimatedTime,
      queuePosition: queuePosition,
      appointment: {
        patientName: appointmentData.patientName,
        time: appointmentData.timeSlot,
        date: appointmentData.appointmentDate.toDate().toISOString(),
        checkInTime: appointmentData.checkInTime?.toDate().toISOString(),
        startConsultationTime: appointmentData.startConsultationTime?.toDate().toISOString(),
        endConsultationTime: appointmentData.endConsultationTime?.toDate().toISOString(),
      },
    };
  } catch (error) {
    logger.error("Erro na Cloud Function getWaitingTime:", error);
    throw new HttpsError("internal", "Ocorreu um erro ao processar a sua solicitação.");
  }
});

// =================== NOVA FUNÇÃO PARA GERAR DADOS DE TESTE ===================
export const seedDatabase = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Apenas utilizadores autenticados podem executar esta ação.");
  }
  
  const adminDoc = await admin.firestore().collection("users").doc(request.auth.uid).get();
  if (adminDoc.data()?.role !== "secretary") {
    throw new HttpsError("permission-denied", "Apenas a secretária pode gerar dados de teste.");
  }

  logger.info("Iniciando a geração de dados de teste...");

  const firstNames = ["Ana", "Bruno", "Carlos", "Daniela", "Eduardo", "Fernanda", "Gustavo", "Helena", "Igor", "Juliana"];
  const lastNames = ["Silva", "Souza", "Costa", "Martins", "Lima", "Ferreira", "Almeida", "Pereira", "Gomes", "Ribeiro"];
  const firestore = admin.firestore();
  const auth = admin.auth();
  const batch = firestore.batch();
  
  const today = new Date();
  let appointmentHour = 8;

  for (let i = 0; i < 10; i++) {
    const firstName = firstNames[Math.floor(Math.random() * firstNames.length)];
    const lastName = lastNames[Math.floor(Math.random() * lastNames.length)];
    const fullName = `${firstName} ${lastName}`;
    const email = `${firstName.toLowerCase()}.${lastName.toLowerCase()}${i}@test.com`;
    const cpf = Math.floor(10000000000 + Math.random() * 90000000000).toString();

    const userRecord = await auth.createUser({
      email: email,
      password: "password123",
      displayName: fullName,
    });

    const userDocRef = firestore.collection("users").doc(userRecord.uid);
    batch.set(userDocRef, {
      uid: userRecord.uid,
      name: fullName,
      cpf: cpf,
      email: email,
      role: "user",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const timeSlot = `${appointmentHour.toString().padStart(2, "0")}:00`;
    const appointmentDate = new Date(today.getFullYear(), today.getMonth(), today.getDate(), appointmentHour, 0, 0);
    
    const appointmentDocRef = firestore.collection("appointments").doc();
    batch.set(appointmentDocRef, {
      patientCpf: cpf,
      patientName: fullName,
      appointmentDate: admin.firestore.Timestamp.fromDate(appointmentDate),
      timeSlot: timeSlot,
      status: "scheduled",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    appointmentHour++;
  }

  await batch.commit();
  logger.info("Dados de teste criados com sucesso.");
  return {message: "10 utilizadores e agendamentos de teste foram criados com sucesso!"};
});