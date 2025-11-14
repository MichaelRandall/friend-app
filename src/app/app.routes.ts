import { Routes } from '@angular/router';
import { FriendListComponent } from './friend-list/friend-list.component';
import { FriendForm } from './friend-form/friend-form';

export const routes: Routes = [
	{ path: '', redirectTo: 'friends', pathMatch: 'full' },
	{ path: 'friends', component: FriendListComponent },
	{ path: 'add', component: FriendForm },
	{ path: '**', redirectTo: 'friends' }
];
