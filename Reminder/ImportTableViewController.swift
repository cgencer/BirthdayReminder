//
//  ImportTableViewController.swift
//  Reminder
//
//  Created by Karthi Ponnusamy on 3/5/17.
//  Copyright © 2017 Karthi Ponnusamy. All rights reserved.
//

import UIKit
import Contacts
import CoreData
import UserNotifications

class ImportTableViewController: UITableViewController {
    
    @IBOutlet var importTabelView: UITableView!
    var managedObjectContext: NSManagedObjectContext?

    var myUsers = [MyUser] ()
    var selectedMyUsers = [MyUser] ()
    var isImportInProcess = false
    var importType = "CONTACT"
    let notificationCenter = UNUserNotificationCenter.current()
    //let center = UNUserNotificationCenter.current()

    override func viewDidLoad() {
        super.viewDidLoad()
    
        self.title = "Import from Contact"
        print(applicationDocumentsDirectory)
        
        
//        let wishAction = UNNotificationAction(identifier: "Wish",
//                                              title: "Wish", options: [])
//        let category = UNNotificationCategory(identifier: "ReminderWishCategory",
//                                              actions: [wishAction],
//                                              intentIdentifiers: [], options: [])
//        notificationCenter.setNotificationCategories([category])
//        center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
//            // Enable or disable features based on authorization.
//        }
    }
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        fetchFromContcts()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
    }
    
    func fetchFromContcts() {
        AppDelegate.getAppDelegate().requestForAccess { (accessGranted) -> Void in
            if accessGranted {

                self.myUsers = [MyUser] ()
                self.selectedMyUsers = [MyUser]()
                
                let keys = [CNContactImageDataKey, CNContactImageDataAvailableKey, CNContactThumbnailImageDataKey, CNContactFormatter.descriptorForRequiredKeys(for: CNContactFormatterStyle.fullName), CNContactEmailAddressesKey, CNContactBirthdayKey] as [Any]
                
                do {
                    let contactStore = AppDelegate.getAppDelegate().contactStore
                    try contactStore.enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys as! [CNKeyDescriptor])) { (contact, pointer) -> Void in
       
                        if let birthday = contact.birthday {
                            //print("\(contact.givenName) birthday >> \("\(birthday.year!)-\(birthday.month!)-\(birthday.day!)")")
 
                            let myUser: MyUser = MyUser()
                            myUser.first_name = contact.givenName
                            myUser.last_name = contact.familyName
                            if contact.birthday != nil {
                                myUser.dob_date = (birthday.day)!
                                myUser.dob_month = (birthday.month)!
                                myUser.dob_year = (birthday.year)!
                                myUser.dob = birthday.date
                            }
                            
                            if contact.imageDataAvailable {
                                //let image = UIImage(data: contact.imageData!)
                                myUser.image_data = contact.imageData!
                                //print("image_data avail for \(contact.givenName)")
                            }
                            
                            self.myUsers.append(myUser)
                            self.selectedMyUsers.append(myUser)
                            
                        } else {
                            //print("birthday not available for \(contact.givenName)")
                        }
                    }
                    
                    DispatchQueue.main.async(execute: { () -> Void in
                        self.isImportInProcess = true
                        self.importTabelView.reloadData()
                    })
                }
                catch let error as NSError {
                    print(error.description, separator: "", terminator: "\n")
                }
            }
        }
    }
    
    func checkBoxClicked(_ sender:UIButton){
        let checkedIndex = sender.tag
        let checkedUser = myUsers[checkedIndex]
        if selectedMyUsers.contains(checkedUser){
            if let index = selectedMyUsers.index(of:checkedUser) {
                selectedMyUsers.remove(at: index)
            }
        } else {
            selectedMyUsers.append(checkedUser)
        }
        self.importTabelView.reloadData()
    }

    func getDateStringFromDate(_ date: Date) -> String! {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale.current
        dateFormatter.dateStyle = DateFormatter.Style.medium
        let dateString = dateFormatter.string(from: date)
        
        return dateString
    }
    
    @IBAction func doImport(_ sender: UIButton) {
        print("import ButtonClicked")
        deleteBeforeInsert()
        notificationCenter.removeAllDeliveredNotifications()

        for user in selectedMyUsers {
            let newUser = User(context: managedObjectContext!)
            newUser.first_name = user.first_name
            newUser.last_name = user.last_name
            
            newUser.dob_date = user.dob_date
            newUser.dob_month = user.dob_month
            newUser.dob_year = user.dob_year
            newUser.dob = user.dob
            newUser.import_type = importType
            
            if let imageData = user.image_data {
                if !newUser.hasPhoto {
                    let nxtPhotoId = User.nextPhotoID() as NSNumber
                    newUser.photo_id = nxtPhotoId
                }
                
                do {
                    try imageData.write(to: newUser.photoURL, options: .atomic)
                    //print("Success writing file: for \(user.first_name)")
                } catch {
                    print("Error writing file: \(error) for \(user.first_name)")
                }
                
                /*
                if let data = UIImageJPEGRepresentation(image, 0.5) {
                    do {
                        try data.write(to: location.photoURL, options: .atomic)
                    } catch {
                        print("Error writing file: \(error)")
                    }
                }
                 */
            }
            
            do {
                try managedObjectContext?.save()
                Helper.addReminderNotification(user: newUser, notificationCenter: notificationCenter, managedObjectContext: managedObjectContext)
            } catch {
                fatalError("Error: \(error)")
            }
            print("save done")
        }
        
        isImportInProcess = false
        //reset cache values
        self.myUsers = [MyUser] ()
        self.selectedMyUsers = [MyUser]()
        performSegue(withIdentifier: "unwindToBirthdayViewController", sender: sender)
    }
    
    func deleteBeforeInsert(){
        let fetchRequest = NSFetchRequest<User>()
        let entity = User.entity()
        fetchRequest.entity = entity
        fetchRequest.predicate = NSPredicate(format: "import_type = %@", "\(importType)")
        //let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
        
        do {
            let fechedUsers = try managedObjectContext!.fetch(fetchRequest)
            for user in fechedUsers {
                try user.deletePhotoFile()
                try user.deleteReminder()
                try managedObjectContext?.delete(user)
            }
            try managedObjectContext?.save()
        }
        catch _ {
            print("Could not delete")
        }
        
        var users = [User] ()
        let fetchRequest2 = NSFetchRequest<User>()
        let entity2 = User.entity()
        fetchRequest2.entity = entity2
        
        let sortDescriptor = NSSortDescriptor(key: "dob_month", ascending: true)
        fetchRequest2.sortDescriptors = [sortDescriptor]
        
        do {
            if managedObjectContext != nil {
                users = try managedObjectContext!.fetch(fetchRequest2)
                print("after delete user count \(users.count)")
            }
        } catch {
            print(error)
        }
    }
    
    let applicationDocumentsDirectory: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }()
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return myUsers.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BirthdayCell") as! BirthdayTabelViewCell
        
        let user = myUsers[indexPath.row]
        cell.nameLabel.text = "\(user.first_name!) \(user.last_name!)"
        if let birthday = user.dob {
            cell.dobLabel.text = getDateStringFromDate(birthday)
        }
        
        if user.image_data != nil {
            let uImage = UIImage(data: user.image_data!)
            cell.diplayImage.image = uImage
        } else {
            let defaultImage = UIImage(named: "default_image")
            cell.diplayImage.image = defaultImage
        }
        
        cell.checkBox.isHidden = false
        var checkBoxImage = UIImage(named:"checkbox_deselect")
        if selectedMyUsers.contains(user){
            checkBoxImage = UIImage(named:"checkbox_select")
        }
            
        cell.checkBox.setBackgroundImage(checkBoxImage, for: UIControlState.normal)
        cell.checkBox.tag = indexPath.row
        cell.checkBox.addTarget(self, action: #selector(ImportTableViewController.checkBoxClicked(_:)), for: .touchUpInside)
    
        return cell
    }
 

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}