"""
Script to encrypt updated vthunder password taken by script ARM_TMPL_3NIC_NVM_VMSS_FUNCTION_APP_4.ps1

"""
import getpass
from cryptography.fernet import Fernet


class SecurePassword:
    def __init__(self):
        self.key = Fernet.generate_key()
        self.key_value = Fernet(self.key)

    def encrypt(self, unencrypted_password):
        self.encrypted_password = self.key_value.encrypt(bytes(unencrypted_password, 'utf-8'))
        return self.key.decode(), self.encrypted_password.decode()

    @staticmethod
    def decrypt(encryption_key, encrypted_password):
        decrypted_password = encryption_key.decrypt(encrypted_password)
        return decrypted_password

    def save(self, key, value):
        pass


def main():
    current_password = getpass.getpass()
    confirm_current_password = getpass.getpass('Confirm Password:')
    if current_password != confirm_current_password:
        # print for powershell script to get status code 401
        print('401')
        return 401

    secure_password = SecurePassword()
    encryption_key, encrypted_password = secure_password.encrypt(
        unencrypted_password=current_password)
    print('%s %s' % (encryption_key, encrypted_password))

main()
