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

import { Injectable } from '@angular/core';

export type NotificationSound = 'chime'|'double_chime'|'soft';

@Injectable({ providedIn: 'root' })
export class NotificationSoundService {
  private enabled = false;
  private sound:NotificationSound = 'chime';
  private context?:AudioContext;
  private lastPlayedAt = 0;

  configure(enabled:boolean, sound:NotificationSound):void {
    this.enabled = enabled;
    this.sound = sound;
  }

  play():void {
    if (!this.enabled || Date.now() - this.lastPlayedAt < 3000) {
      return;
    }

    this.lastPlayedAt = Date.now();
    this.playSound(this.sound);
  }

  preview(sound:NotificationSound):void {
    this.playSound(sound);
  }

  private playSound(sound:NotificationSound):void {
    const context = this.context ||= new AudioContext();
    const now = context.currentTime;
    const frequencies = sound === 'double_chime' ? [740, 988] : sound === 'soft' ? [523] : [659, 880];

    frequencies.forEach((frequency, index) => {
      const oscillator = context.createOscillator();
      const gain = context.createGain();
      const start = now + index * 0.14;

      oscillator.frequency.value = frequency;
      oscillator.type = 'sine';
      gain.gain.setValueAtTime(sound === 'soft' ? 0.035 : 0.07, start);
      gain.gain.exponentialRampToValueAtTime(0.001, start + 0.22);
      oscillator.connect(gain).connect(context.destination);
      oscillator.start(start);
      oscillator.stop(start + 0.23);
    });
  }
}
