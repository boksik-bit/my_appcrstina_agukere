import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let ctx = controller.viewContext
        let calendar = Calendar.current
        let now = Date()

        let sampleProducts: [(String, String, String)] = [
            ("White Bread", "Bakery", "loaf"),
            ("Whole Milk", "Dairy", "gallon"),
            ("Gasoline", "Transport", "gallon"),
            ("Rice", "Groceries", "kg"),
            ("Eggs", "Dairy", "dozen"),
            ("Ground Coffee", "Beverages", "pack")
        ]

        var productObjects: [NSManagedObject] = []

        for (name, category, unit) in sampleProducts {
            let entity = NSEntityDescription.entity(forEntityName: "Product", in: ctx)!
            let product = NSManagedObject(entity: entity, insertInto: ctx)
            product.setValue(UUID(), forKey: "id")
            product.setValue(name, forKey: "name")
            product.setValue(category, forKey: "category")
            product.setValue(unit, forKey: "unit")
            product.setValue(now, forKey: "createdAt")
            productObjects.append(product)
        }

        let basePrices: [Double] = [3.49, 4.29, 3.59, 2.99, 3.89, 9.99]

        for monthOffset in stride(from: -6, through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .month, value: monthOffset, to: now) else { continue }
            for (i, product) in productObjects.enumerated() {
                let growth = 1.0 + Double(monthOffset + 6) * Double.random(in: 0.005...0.025)
                let price = basePrices[i] * growth
                let entity = NSEntityDescription.entity(forEntityName: "PriceRecord", in: ctx)!
                let record = NSManagedObject(entity: entity, insertInto: ctx)
                record.setValue(UUID(), forKey: "id")
                record.setValue(date, forKey: "date")
                record.setValue(price, forKey: "price")
                record.setValue(product, forKey: "product")
            }
        }

        let settingsEntity = NSEntityDescription.entity(forEntityName: "UserSettings", in: ctx)!
        let settings = NSManagedObject(entity: settingsEntity, insertInto: ctx)
        settings.setValue(UUID(), forKey: "id")
        settings.setValue("USD", forKey: "currency")
        settings.setValue(5000.0, forKey: "salary")
        settings.setValue(3000.0, forKey: "budget")
        settings.setValue(1, forKey: "reminderDay")
        settings.setValue(false, forKey: "reminderEnabled")

        try? ctx.save()
        return controller
    }()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    init(inMemory: Bool = false) {
        let model = Self.buildModel()
        container = NSPersistentContainer(name: "BasketCheck", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        let coordinator = container.persistentStoreCoordinator
        container.loadPersistentStores { description, error in
            guard let error else { return }
            print("Core Data load failed: \(error.localizedDescription)")
            guard let url = description.url else { return }
            do {
                try coordinator.destroyPersistentStore(at: url, type: .sqlite, options: nil)
                _ = try coordinator.addPersistentStore(type: .sqlite, configuration: nil, at: url, options: nil)
            } catch {
                print("Core Data recovery failed, using in-memory store: \(error.localizedDescription)")
                _ = try? coordinator.addPersistentStore(type: .inMemory, configuration: nil, at: URL(fileURLWithPath: "/dev/null"), options: nil)
            }
        }

        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
        } catch {
            print("Core Data save error: \(error)")
        }
    }

    // MARK: - Programmatic Model

    private static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let product = NSEntityDescription()
        product.name = "Product"
        product.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let priceRecord = NSEntityDescription()
        priceRecord.name = "PriceRecord"
        priceRecord.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        let userSettings = NSEntityDescription()
        userSettings.name = "UserSettings"
        userSettings.managedObjectClassName = NSStringFromClass(NSManagedObject.self)

        // Product attributes
        let pId = makeAttribute("id", .UUIDAttributeType)
        let pName = makeAttribute("name", .stringAttributeType)
        let pCategory = makeAttribute("category", .stringAttributeType, optional: true, defaultValue: "General")
        let pUnit = makeAttribute("unit", .stringAttributeType, defaultValue: "piece")
        let pPhoto = makeAttribute("photoData", .binaryDataAttributeType, optional: true)
        let pCreated = makeAttribute("createdAt", .dateAttributeType)

        // PriceRecord attributes
        let rId = makeAttribute("id", .UUIDAttributeType)
        let rDate = makeAttribute("date", .dateAttributeType)
        let rPrice = makeAttribute("price", .doubleAttributeType)

        // Relationships
        let recordToProduct = NSRelationshipDescription()
        recordToProduct.name = "product"
        recordToProduct.destinationEntity = product
        recordToProduct.maxCount = 1
        recordToProduct.minCount = 1
        recordToProduct.deleteRule = .nullifyDeleteRule

        let productToRecords = NSRelationshipDescription()
        productToRecords.name = "priceRecords"
        productToRecords.destinationEntity = priceRecord
        productToRecords.maxCount = 0
        productToRecords.deleteRule = .cascadeDeleteRule

        recordToProduct.inverseRelationship = productToRecords
        productToRecords.inverseRelationship = recordToProduct

        product.properties = [pId, pName, pCategory, pUnit, pPhoto, pCreated, productToRecords]
        priceRecord.properties = [rId, rDate, rPrice, recordToProduct]

        // UserSettings attributes
        let sId = makeAttribute("id", .UUIDAttributeType)
        let sCurrency = makeAttribute("currency", .stringAttributeType, defaultValue: "USD")
        let sSalary = makeAttribute("salary", .doubleAttributeType, optional: true, defaultValue: 0.0)
        let sBudget = makeAttribute("budget", .doubleAttributeType, optional: true, defaultValue: 0.0)
        let sReminderDay = makeAttribute("reminderDay", .integer16AttributeType, defaultValue: 1)
        let sReminderEnabled = makeAttribute("reminderEnabled", .booleanAttributeType, defaultValue: false)

        userSettings.properties = [sId, sCurrency, sSalary, sBudget, sReminderDay, sReminderEnabled]

        model.entities = [product, priceRecord, userSettings]
        return model
    }

    private static func makeAttribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.isOptional = optional
        if let defaultValue { attr.defaultValue = defaultValue }
        if type == .binaryDataAttributeType { attr.allowsExternalBinaryDataStorage = true }
        return attr
    }
}
