require("dotenv").config({ path: __dirname + "/.env" });

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const cors = require("cors")({ origin: true });
const { GoogleGenAI, Type } = require("@google/genai");

admin.initializeApp();

exports.generateStudentAiHelperHttp = functions.https.onRequest((req, res) => {
  cors(req, res, async () => {
    try {
      res.set("Access-Control-Allow-Origin", "*");
      res.set("Access-Control-Allow-Headers", "Content-Type");
      res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");

      if (req.method === "OPTIONS") {
        return res.status(204).send("");
      }

      if (req.method !== "POST") {
        return res.status(405).json({
          success: false,
          error: "Method not allowed. Use POST."
        });
      }

      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey || !apiKey.trim()) {
        return res.status(500).json({
          success: false,
          error: "GEMINI_API_KEY is missing in functions/.env"
        });
      }

      const ai = new GoogleGenAI({ apiKey });

      const data = req.body || {};
      const peripherals = data.peripherals || {};

      const comment = String(data.comment || "").trim();
      const pcCode = String(data.pcCode || "").trim();
      const lab = String(data.lab || "").trim();
      const pc = String(data.pc || "").trim();

      const prompt = `
You are an AI helper for a school computer lab reporting system.

Rules:
1. Students are NOT technicians.
2. Give only simple, safe troubleshooting steps.
3. If the issue is still not solved, escalate to ITSO.
4. Keep the answer short and clear.
5. Output valid JSON only.

Workstation:
PC Code: ${pcCode}
Lab: ${lab}
PC: ${pc}

Student comment:
${comment}

Peripherals:
mouse: ${peripherals.mouse}
keyboard: ${peripherals.keyboard}
monitor: ${peripherals.monitor}
cables: ${peripherals.cables}
system_unit: ${peripherals.system_unit}
`;

      const response = await ai.models.generateContent({
        model: "gemini-2.5-flash",
        contents: prompt,
        config: {
          responseMimeType: "application/json",
          responseSchema: {
            type: Type.OBJECT,
            properties: {
              category: { type: Type.STRING },
              priority: {
                type: Type.STRING,
                enum: ["Low", "Medium", "High", "Critical"]
              },
              student_tip: { type: Type.STRING },
              escalate_to_itso: { type: Type.BOOLEAN },
              itso_action: { type: Type.STRING },
              action_done_template: { type: Type.STRING }
            },
            required: [
              "category",
              "priority",
              "student_tip",
              "escalate_to_itso",
              "itso_action",
              "action_done_template"
            ]
          }
        }
      });

      const rawText = String(response.text || "").trim();

      if (!rawText) {
        return res.status(502).json({
          success: false,
          error: "Gemini returned an empty response."
        });
      }

      const result = JSON.parse(rawText);

      return res.status(200).json({
        success: true,
        result
      });
    } catch (error) {
      console.error("FUNCTION ERROR:", error);
      return res.status(500).json({
        success: false,
        error: error?.message || "Unknown server error"
      });
    }
  });
});