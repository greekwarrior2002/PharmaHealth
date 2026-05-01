import SwiftUI

extension Color {
    static let mbPrimary = Color("mbPrimary")
    static let mbSurface = Color("mbSurface")
    static let mbBackground = Color("mbBackground")
    static let mbUrgent = Color("mbUrgent")
    static let mbDanger = Color("mbDanger")
    static let mbGood = Color("mbGood")
}

extension View {
    func mbCard() -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.mbSurface)
                    .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
            )
    }

    func mbPrimaryButton() -> some View {
        self
            .font(.headline)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.mbPrimary)
            )
    }
}

extension Date {
    func mbShort() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: self)
    }

    func mbDateTime() -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: self)
    }
}

extension String {
    var phoneURL: URL? {
        let digits = self.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }
}

enum CommonMedications {
    static let names: [String] = [
        "Lisinopril", "Atorvastatin", "Metformin", "Levothyroxine", "Amlodipine",
        "Metoprolol", "Albuterol", "Omeprazole", "Losartan", "Gabapentin",
        "Hydrochlorothiazide", "Simvastatin", "Sertraline", "Furosemide", "Acetaminophen",
        "Ibuprofen", "Aspirin", "Pantoprazole", "Citalopram", "Escitalopram",
        "Tamsulosin", "Carvedilol", "Tramadol", "Cyclobenzaprine", "Trazodone",
        "Bupropion", "Clopidogrel", "Warfarin", "Apixaban", "Rivaroxaban",
        "Insulin Glargine", "Insulin Aspart", "Glipizide", "Pravastatin", "Rosuvastatin",
        "Fluoxetine", "Duloxetine", "Venlafaxine", "Alprazolam", "Lorazepam",
        "Prednisone", "Montelukast", "Loratadine", "Cetirizine", "Diphenhydramine",
        "Allopurinol", "Finasteride", "Sildenafil", "Donepezil", "Memantine"
    ]
}
