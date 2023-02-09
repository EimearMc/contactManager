import UIKit
import CoreData
import UserNotifications

class Contact {
    var name: String
    var phoneNumber: String
    var birthdate: Date
    
    init(name: String, phoneNumber: String, birthdate: Date) {
        self.name = name
        self.phoneNumber = phoneNumber
        self.birthdate = birthdate
    }
}

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UNUserNotificationCenterDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var contacts = [Contact]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Fetch stored contacts from Core Data
        fetchContacts()
        // Register for local notifications
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Table View Data Source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell", for: indexPath)
        let contact = contacts[indexPath.row]
        cell.textLabel?.text = contact.name
        cell.detailTextLabel?.text = contact.phoneNumber
        return cell
    }
    
    // MARK: - Table View Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let contact = contacts[indexPath.row]
        // Initiate phone call
        if let phoneCallURL = URL(string: "tel://\(contact.phoneNumber)"),
            UIApplication.shared.canOpenURL(phoneCallURL) {
            UIApplication.shared.open(phoneCallURL, options: [:], completionHandler: nil)
        }
    }
    
    // MARK: - Core Data
    
    func fetchContacts() {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        do {
            let contactEntities = try managedContext.fetch(fetchRequest)
            contacts = contactEntities.map { contactEntity in
                Contact(name: contactEntity.value(forKey: "name") as! String,
                        phoneNumber: contactEntity.value(forKey: "phoneNumber") as! String,
                        birthdate: contactEntity.value(forKey: "birthdate") as! Date)
            }
            tableView.reloadData()
            scheduleBirthdayNotifications()
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
    }
    
    func saveContact(_ contact: Contact) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        let entity = NSEntityDescription.entity(forEntityName: "ContactEntity", in: managedContext)!
        let contactEntity = NSManagedObject(entity: entity, insertInto: managedContext)
        contactEntity.setValue(contact.name, forKey: "name")
        contactEntity.setValue(contact.phoneNumber, forKey: "phoneNumber")
        contactEntity.setValue(contact.birthdate, forKey: "birthdate")
        do {
            try managedContext.save()
            contacts.append(contact)
            tableView.reloadData()
            scheduleBirthdayNotification(for: contact)
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    func updateContact(_ contact: Contact, at index: Int) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        do {
            let contactEntities = try managedContext.fetch(fetchRequest)
            let contactEntity = contactEntities[index]
            contactEntity.setValue(contact.name, forKey: "name")
            contactEntity.setValue(contact.phoneNumber, forKey: "phoneNumber")
            contactEntity.setValue(contact.birthdate, forKey: "birthdate")
            try managedContext.save()
            contacts[index] = contact
            tableView.reloadData()
            removeBirthdayNotification(for: contacts[index])
            scheduleBirthdayNotification(for: contact)
        } catch let error as NSError {
            print("Could not update. \(error), \(error.userInfo)")
        }
    }
    
    func deleteContact(at index: Int) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ContactEntity")
        do {
            let contactEntities = try managedContext.fetch(fetchRequest)
            managedContext.delete(contactEntities[index])
            try managedContext.save()
            contacts.remove(at: index)
            tableView.reloadData()
            removeBirthdayNotification(for: contacts[index])
        } catch let error as NSError {
            print("Could not delete.\(error), \(error.userInfo)")
        }
    }
    
    func scheduleBirthdayNotification(for contact: Contact) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Birthday Reminder"
        content.body = "Today is \(contact.name)'s birthday!"
        content.sound = UNNotificationSound.default
        
        let dateComponents = Calendar.current.dateComponents([.month, .day], from: contact.birthdate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: contact.phoneNumber, content: content, trigger: trigger)
        
        center.add(request) { (error) in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    func removeBirthdayNotification(for contact: Contact) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [contact.phoneNumber])
    }
    
    func scheduleBirthdayNotifications() {
        for contact in contacts {
            scheduleBirthdayNotification(for: contact)
        }
    }
}

// MARK: - UITableViewDataSource

extension PhonebookViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell", for: indexPath) as! ContactTableViewCell
        let contact = contacts[indexPath.row]
        cell.nameLabel.text = contact.name
        cell.phoneNumberLabel.text = contact.phoneNumber
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteContact(at: indexPath.row)
        }
    }
}

// MARK: - UITableViewDelegate

extension PhonebookViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let contact = contacts[indexPath.row]
        let alertController = UIAlertController(title: "Call \(contact.name)?", message: "", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let callAction  = UIAlertAction(title: "Call", style: .default) { _ in
            if let url = URL(string: "tel://\(contact.phoneNumber)"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
        alertController.addAction(cancelAction)
        alertController.addAction(callAction)
        present(alertController, animated: true, completion: nil)
    }
}


