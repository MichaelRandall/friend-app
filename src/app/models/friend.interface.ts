export interface PhoneNumber {
  id?: number;
  type: 'home' | 'work' | 'mobile';
  number: string;
}

export interface Friend {
  id?: number;
  friendName: string;
  phoneNumbers: PhoneNumber[];
}
