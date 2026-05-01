import SwiftUI
import SwiftData

struct AddAppointmentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var doctorName = ""
    @State private var specialty = ""
    @State private var date = Date().addingTimeInterval(60 * 60 * 24 * 7)
    @State private var location = ""
    @State private var errorMessage: String?

    private var canSave: Bool {
        !doctorName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Doctor") {
                    TextField("Doctor name", text: $doctorName)
                        .textInputAutocapitalization(.words)
                    TextField("Specialty (optional)", text: $specialty)
                }
                Section("When and where") {
                    DatePicker("Date and time", selection: $date)
                    TextField("Location (optional)", text: $location)
                }
            }
            .navigationTitle("New Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .alert("Cannot save", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        let appt = Appointment(
            doctorName: doctorName.trimmingCharacters(in: .whitespaces),
            specialty: specialty.trimmingCharacters(in: .whitespaces),
            date: date,
            location: location.trimmingCharacters(in: .whitespaces)
        )
        context.insert(appt)
        do {
            try context.save()
            NotificationManager.shared.scheduleAppointmentReminder(for: appt)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
