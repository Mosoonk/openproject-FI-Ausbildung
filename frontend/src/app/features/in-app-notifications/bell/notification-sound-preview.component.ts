//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.
//++

import { ChangeDetectionStrategy, Component, ElementRef, Input, inject } from '@angular/core';
import { NotificationSound, NotificationSoundService } from 'core-app/features/in-app-notifications/bell/state/notification-sound.service';
import { populateInputsFromDataset } from 'core-app/shared/components/dataset-inputs';

@Component({
  selector: 'opce-notification-sound-preview',
  template: '<button class="Button Button--secondary" type="button" (click)="play()">{{ label }}</button>',
  styles: [`
    :host
      display: block
      margin-top: 12px
  `],
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class NotificationSoundPreviewComponent {
  readonly notificationSound = inject(NotificationSoundService);
  readonly elementRef = inject<ElementRef<HTMLElement>>(ElementRef);

  @Input() sound:NotificationSound = 'chime';
  @Input() label = '';

  constructor() {
    populateInputsFromDataset(this);
  }

  play():void {
    const selectedSound = document.querySelector<HTMLSelectElement>('select[name="pref[notification_sound][sound]"]')?.value;
    this.notificationSound.preview(this.isSound(selectedSound) ? selectedSound : this.sound);
  }

  private isSound(value:string|undefined):value is NotificationSound {
    return value === 'chime' || value === 'double_chime' || value === 'soft';
  }
}
